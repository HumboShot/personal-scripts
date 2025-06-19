import os

def create_folders_from_files_in_directory(directory_path):
    # Check if the provided path is a valid directory
    if not os.path.isdir(directory_path):
        print("The provided path is not a valid directory.")
        return

    # Iterate through all files in the directory
    for file_name in os.listdir(directory_path):
        # Skip directories
        if os.path.isdir(os.path.join(directory_path, file_name)):
            continue

        # Extract the filename without the extension
        base_name, extension = os.path.splitext(file_name)

        # Check if the file is a .jpg file or has no extension
        if extension.lower() == '.jpg' or extension == '':
            # Append " ()" to the folder name
            folder_name = f"{base_name} ()"

            # Determine the folder path
            folder_path = os.path.join(directory_path, folder_name)

            # Create the folder if it doesn't already exist
            if not os.path.exists(folder_path):
                os.makedirs(folder_path)
                print(f"Folder '{folder_name}' created at: {folder_path}")
            else:
                print(f"Folder '{folder_name}' already exists at: {folder_path}")

# Example usage
directory = r"F:"  # Replace with the path to your directory
create_folders_from_files_in_directory(directory)