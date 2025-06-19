import os
import re

def create_folders_for_pdfs(directory):
    # Ensure the directory exists
    if not os.path.exists(directory):
        print(f"Directory '{directory}' does not exist.")
        return

    # Iterate through all files in the directory
    for filename in os.listdir(directory):
        # Check if the file is a PDF
        if filename.endswith('.pdf'):
            # Remove numbers at the end of the file name (before the extension)
            folder_name = re.sub(r'\d+(?=\.pdf$)', '', filename).rstrip('.').rstrip()
            folder_name = folder_name.replace('.pdf', '')

            # Create the folder path
            folder_path = os.path.join(directory, folder_name)

            # Create the folder if it doesn't already exist
            if not os.path.exists(folder_path):
                os.makedirs(folder_path)
                print(f"Created folder: {folder_path}")
            else:
                print(f"Folder already exists: {folder_path}")

# Example usage
directory_path = r"D:\Downloads\HManga"  # Replace with your directory path
create_folders_for_pdfs(directory_path)