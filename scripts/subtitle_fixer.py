import os
import shutil
import asyncclick as click
import asyncio
import re

def is_english_subtitle(filename):
    """
    Check if a subtitle file is English based on filename patterns.

    Matches:
    - Files containing "English" (case insensitive)
    - Files with "_eng" pattern (preceded by non-letter and followed by non-letter)
    - Files with ".eng" pattern (preceded by non-letter and followed by non-letter)

    Avoids false positives like "obeng" or "engob".
    """
    filename_lower = filename.lower()

    # Check for "english" in the filename
    if 'english' in filename_lower:
        return True

    # Check for "_eng" or ".eng" patterns with word boundaries
    # This matches "_eng.", "_eng_", ".eng.", ".eng_" but not "obeng" or "engob"
    eng_pattern = r'[._]eng[._]'
    if re.search(eng_pattern, filename_lower):
        return True

    return False

@click.command()
@click.argument('series_dir', type=click.Path(exists=True, file_okay=False, dir_okay=True))
async def organize_subtitles(series_dir):
    subs_dir = "Subs"
    entries = os.listdir(series_dir)
    video_files = [f for f in entries if f.endswith('.mp4') or f.endswith('.mkv')]
    if not video_files:
        print(f"No .mp4 video files found in the directory: {series_dir}")
        return

    print(f"Found {len(video_files)} video files in {series_dir}. Processing...")

    # Loop through each video file
    for video_file in video_files:
        # Construct the expected subtitle folder name based on the video file name
        sub_folder_name = os.path.splitext(video_file)[0]
        full_sub_path = os.path.join(series_dir, subs_dir, sub_folder_name)

        # Check if the subtitle folder exists
        if not os.path.isdir(full_sub_path):
            print(f"Subtitle folder not found for {video_file}. Skipping.")
            continue

        print(f"Processing subtitles for: {video_file}")

        # Find all .srt files in the subtitle folder that are English
        try:
            subtitle_files = os.listdir(full_sub_path)
            english_subs = [
                f for f in subtitle_files
                if f.endswith('.srt') and is_english_subtitle(f)
            ]
        except FileNotFoundError:
            print(f"Could not access subtitle folder: {full_sub_path}. Skipping.")
            continue

        if not english_subs:
            print(f"No English subtitles found for {video_file}. Skipping.")
            continue

        # Find the "best" English subtitle file by checking the file size.
        # Larger files are often more complete.
        best_sub_file = max(
            english_subs,
            key=lambda f: os.path.getsize(os.path.join(full_sub_path, f))
        )

        # Define the source and destination paths
        source_sub_path = os.path.join(full_sub_path, best_sub_file)
        destination_sub_path = os.path.join(
            series_dir,
            f"{sub_folder_name}.srt"
        )

        # Copy the file to the parent directory and rename it
        shutil.copyfile(source_sub_path, destination_sub_path)
        print(f"Successfully copied and renamed '{best_sub_file}' to '{os.path.basename(destination_sub_path)}'.")

    print("\nSubtitle organization complete.")

if __name__ == "__main__":
    asyncio.run(organize_subtitles())
