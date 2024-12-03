import zipfile
import tarfile

# 10. Создание ZIP архива
def create_zip_archive(file_paths, archive_path):
    with zipfile.ZipFile(archive_path, 'w') as zipf:
        for file in file_paths:
            zipf.write(file, os.path.basename(file))

# 11. Извлечение файлов из ZIP архива
def extract_zip_archive(archive_path, extract_path):
    with zipfile.ZipFile(archive_path, 'r') as zipf:
        zipf.extractall(extract_path)

# 12. Создание TAR архива
def create_tar_archive(file_paths, archive_path):
    with tarfile.open(archive_path, 'w:gz') as tar:
        for file in file_paths:
            tar.add(file, arcname=os.path.basename(file))

# 13. Извлечение файлов из TAR архива
def extract_tar_archive(archive_path, extract_path):
    with tarfile.open(archive_path, 'r:*') as tar:
        tar.extractall(path=extract_path)