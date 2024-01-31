#!/usr/bin/env python3
#ported from https://github.com/irbujam/ss_log_event_monitor/blob/main/parse_ss_farmer_log.ps1

import os
import subprocess
import re
from collections import defaultdict

# Function to clear the screen
def clear_screen():
    os.system('clear')

# Initialize state
distinct_disk_farms = set()
reward_count = 0
reward_by_disk = defaultdict(int)
plot_size_by_disk = defaultdict(lambda: "0%")
errors = []
total_error_count = 0

# Function to process a single line of log data
def process_log_line(line):
    global distinct_disk_farms, reward_count, reward_by_disk, plot_size_by_disk, errors, total_error_count

    if "Single disk farm" in line:
        disk_num = re.search(r"Single disk farm (\d+):", line)
        if disk_num and disk_num.group(1) not in distinct_disk_farms:
            distinct_disk_farms.add(disk_num.group(1))
    elif "Successfully signed reward hash" in line:
        reward_count += 1
        disk_num = re.search(r"{disk_farm_index=(\d+)}", line)
        if disk_num:
            reward_by_disk[disk_num.group(1)] += 1
    elif "plotting" in line:
        disk_num = re.search(r"{disk_farm_index=(\d+)}", line)
        if disk_num:
            disk_info = disk_num.group(1)
            if "Replotting complete" in line:
                plot_size_by_disk[disk_info] = "100%"
            else:
                plot_size = re.search(r"\((\d+)%", line)
                if plot_size:
                    plot_size_by_disk[disk_info] = plot_size.group(1) + "%"
    elif "error" in line and "WARN quinn_udp: sendmsg error:" not in line:
        total_error_count += 1
        if len(errors) >= 5:
            errors.pop(0)
        errors.append(line)

# Function to display current state
def display_current_state():
    clear_screen()
    print("------------------------")
    print("Summary:")
    print("------------------------")
    print("Total Rewards:", reward_count)
    print("Total Disk Farms:", len(distinct_disk_farms))
    print("Total Errors:", total_error_count)
    print("------------------------")
    print("Disk#", "Rewards", "Plot Status")
    print("------------------------")
    for disk in distinct_disk_farms:
        print(disk, "  ", reward_by_disk.get(disk, 0), "    ", plot_size_by_disk.get(disk, "0%"))
    
    if errors:
        print("\nRecent Errors (last 5):")
        print("------------------------")
        for error in errors:
            print(error)

# Main function
def main():
    # Fetch complete existing log data for initial parsing
    historical_cmd = ["journalctl", "--user-unit=subspace-farmer"]
    proc = subprocess.Popen(historical_cmd, stdout=subprocess.PIPE, text=True)
    historical_data, _ = proc.communicate()

    # Process historical data
    for line in historical_data.split('\n'):
        process_log_line(line)

    display_current_state()

    # Start streaming new log entries
    streaming_cmd = ["journalctl", "--user-unit=subspace-farmer", "-f"]
    with subprocess.Popen(streaming_cmd, stdout=subprocess.PIPE, text=True) as stream_proc:
        try:
            while True:
                line = stream_proc.stdout.readline()
                if line:
                    process_log_line(line)
                    display_current_state()
        except KeyboardInterrupt:
            stream_proc.terminate()

if __name__ == "__main__":
    main()
