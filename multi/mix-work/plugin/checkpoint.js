/**
 * OpenCode Global Plugin: Shadow Git Checkpoints
 * 
 * This plugin is intentionally lightweight and uses CLI commands
 * to avoid module resolution issues in the OpenCode plugin system.
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { join } from 'path';

/** @type {import('@opencode-ai/plugin').Plugin} */
export const CheckpointPlugin = async ({ directory }) => {
  console.log('[Checkpoint] Plugin loaded for:', directory);
  
  // Helper to run checkpoint CLI commands
  const runCheckpointCLI = async (args) => {
    return new Promise((resolve, reject) => {
      try {
        const result = execSync(`checkpoint-cli ${args.join(' ')}`, {
          cwd: directory,
          encoding: 'utf8',
          stdio: 'pipe'
        });
        resolve(result);
      } catch (error) {
        reject(error);
      }
    });
  };
  
  // Check if shadow git is initialized
  const shadowPath = join(directory, '.opencode', 'checkpoints');
  if (!existsSync(shadowPath)) {
    console.log('[Checkpoint] Shadow Git not initialized yet. Will initialize on first edit.');
  } else {
    try {
      const result = await runCheckpointCLI(['status', '--json']);
      const status = JSON.parse(result);
      if (status.checkpoints?.total > 0) {
        console.log(`[Checkpoint] Found ${status.checkpoints.total} existing checkpoints`);
      }
    } catch (error) {
      // Silent fail - maybe CLI not available yet
    }
  }
  
  let debounceTimeout = null;
  
  return {
    // Auto-create checkpoints on file edits
    'file.edited': async () => {
      // Debounce checkpoint creation
      if (debounceTimeout) {
        clearTimeout(debounceTimeout);
      }
      
      debounceTimeout = setTimeout(async () => {
        try {
          await runCheckpointCLI(['create', '--auto', '--message', '"Auto-checkpoint from OpenCode"']);
          console.log('[Checkpoint] ✓ Auto-checkpoint created');
        } catch (error) {
          // Silent fail if no changes
          if (!error.message?.includes('No changes')) {
            console.log('[Checkpoint] Note: Could not create checkpoint (may be no changes)');
          }
        }
      }, 5000);
    },
    
    // Create checkpoint before session ends
    'session.idle': async () => {
      try {
        await runCheckpointCLI(['create', '--type', 'session', '--message', '"Session idle checkpoint"']);
        console.log('[Checkpoint] ✓ Session checkpoint created');
      } catch (error) {
        // Silent fail
      }
    },
    
    // Emergency checkpoint on errors
    'session.error': async ({ error }) => {
      try {
        const msg = error?.message || 'Unknown error';
        await runCheckpointCLI(['create', '--type', 'emergency', '--message', `"Emergency: ${msg}"`]);
        console.log('[Checkpoint] 🚨 Emergency checkpoint created');
      } catch (err) {
        // Silent fail
      }
    },
  };
};

export default CheckpointPlugin;
