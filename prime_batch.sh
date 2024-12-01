#!/bin/bash
#SBATCH --partition=Tunninet         # Partition to run on
#SBATCH --job-name=prime_calc        # Job name
#SBATCH --nodes=4                    # Number of nodes
#SBATCH --ntasks=64                  # Total tasks (16 tasks per node)
#SBATCH --ntasks-per-node=16         # Tasks per node
#SBATCH --cpus-per-task=1            # CPUs per task
#SBATCH --output=slurm-%j.out        # Standard output
#SBATCH --time=00:20:00              # Max time

# Go to the submit directory
cd $SLURM_SUBMIT_DIR

# Load necessary modules or set up the environment
# module load python/3.8.5  # Uncomment and adjust if using modules

# Ensure 'get_cpu' is executable
chmod +x get_cpu

# Record the start time
job_start_time=$(date +%s)

# Define the range of numbers
START=1
END=1000000
CHUNK_SIZE=$(( (END - START + 1) / SLURM_NTASKS ))
REMAINDER=$(( (END - START + 1) % SLURM_NTASKS ))

echo "START=$START, END=$END, SLURM_NTASKS=$SLURM_NTASKS, CHUNK_SIZE=$CHUNK_SIZE, REMAINDER=$REMAINDER" > debug.log

# Export variables for srun
export START END CHUNK_SIZE REMAINDER

# Run tasks using srun; Slurm will distribute tasks across nodes and cores
srun --cpu-bind=cores bash -c '
  start_time=$(date +%s)
  node=$(hostname)
  core=$(./get_cpu)
  TASK_ID=$SLURM_PROCID
  TASK_START=$((START + TASK_ID * CHUNK_SIZE))
  TASK_END=$((TASK_START + CHUNK_SIZE - 1))
  if [ $TASK_ID -eq $((SLURM_NTASKS - 1)) ]; then
    TASK_END=$((TASK_END + REMAINDER))
  fi
  {
    echo Node: $node
    echo Core: $core
    echo Range: $TASK_START to $TASK_END
    python3 prime_search.py $TASK_START $TASK_END 2> errors_${TASK_START}_${TASK_END}.log
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo Duration: $duration seconds
  } > task_${TASK_START}_${TASK_END}.log
'

# Record the end time
job_end_time=$(date +%s)

# Calculate total run time
job_duration=$((job_end_time - job_start_time))

# Convert duration to HH:MM:SS format
hours=$((job_duration / 3600))
minutes=$(( (job_duration % 3600) / 60 ))
seconds=$((job_duration % 60))

# Output total run time to run_time.txt
printf "Total run time: %02d:%02d:%02d (HH:MM:SS)\n" $hours $minutes $seconds > run_time.txt

# Aggregate task logs in order
{
  for file in $(ls task_* | sort -t_ -k2 -n); do
    cat "$file"
  done
} > all_tasks.log

# Merge prime results in order
{
  for file in $(ls primes_* | sort -t_ -k2 -n); do
    cat "$file"
  done
} > all_primes.txt

# Count the total number of primes found
total_primes=$(wc -l < all_primes.txt)

# Output the total number of primes to results.txt
echo "Total number of primes found between $START and $END: $total_primes" > results.txt

echo "Prime number search completed. Results in all_primes.txt. Task mapping in all_tasks.log" >> debug.log

# Cleanup temporary files
rm -f task_*.log primes_*.txt errors_*.log

