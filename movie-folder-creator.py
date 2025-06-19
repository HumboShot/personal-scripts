import os
import shutil
import re

# Define the directory to organize
directory_path = r'Z:\Movies'  # Use a raw string to avoid invalid escape sequences

# Iterate through all files in the directory
for file_name in os.listdir(directory_path):
    file_path = os.path.join(directory_path, file_name)

    # Ignore directories
    if os.path.isdir(file_path):
        continue

    # Check if the file has a .mkv extension
    if file_name.lower().endswith('.mkv'):
        # Remove text inside {} from the file name for folder creation
        folder_name = re.sub(r'\{.*?\}', '', file_name).strip()
        folder_name = os.path.splitext(folder_name)[0]  # Remove the file extension
        folder_name = folder_name.rstrip('.')  # Remove trailing dots (if any)
        folder_name = folder_name.strip()  # Remove leading/trailing whitespace

        # Create the folder if it doesn't exist
        folder_path = os.path.join(directory_path, folder_name)
        if not os.path.exists(folder_path):
            os.makedirs(folder_path)

        # Move the .mkv file into the folder
        new_file_path = os.path.join(folder_path, file_name)
        shutil.move(file_path, new_file_path)
        print(f"Moved: {file_name} to {folder_path}")