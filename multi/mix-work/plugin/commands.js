/**
 * OpenCode Custom Commands for Checkpoints
 */

import { spawn } from 'child_process';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

/** @type {import('@opencode-ai/plugin').Plugin} */
export const CheckpointCommands = async ({ project, client, $, directory, worktree }) => {
  return {
    // /checkpoint-review command
    'tui.command.execute': async ({ command, args }) => {
      if (command === 'checkpoint-review' || command === 'review-checkpoints') {
        console.log('[Checkpoint] Opening visual diff review...');
        
        try {
          // Find the checkpoint-review binary
          const binPath = join(dirname(__dirname), 'bin', 'checkpoint-review');
          
          // Spawn the TUI in the current directory
          const child = spawn(binPath, [], {
            cwd: directory,
            stdio: 'inherit',
            env: process.env
          });
          
          child.on('error', (error) => {
            console.error('[Checkpoint] Failed to launch review TUI:', error.message);
            console.error('[Checkpoint] Make sure the binary is compiled: npm run build:go');
          });
          
          child.on('exit', (code) => {
            if (code === 0) {
              console.log('[Checkpoint] Review completed');
            } else if (code !== null) {
              console.error(`[Checkpoint] Review exited with code ${code}`);
            }
          });
        } catch (error) {
          console.error('[Checkpoint] Error:', error.message);
        }
      }
    }
  };
};

export default CheckpointCommands;
