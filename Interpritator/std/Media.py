import os
import wave
import array
from PIL import Image

# Функции для работы с изображениями

def image_info(path):
    """Получить информацию об изображении"""
    try:
        with Image.open(path) as img:
            return {
                "format": img.format,
                "mode": img.mode,
                "size": img.size,
            }
    except IOError:
        return None

def resize_image(path, size):
    """Изменить размер изображения"""
    with Image.open(path) as img:
        resized = img.resize(size)
        resized.save(path)

def convert_image_format(input_path, output_path, format):
    """Конвертировать формат изображения"""
    with Image.open(input_path) as img:
        img.save(output_path, format=format)

def rotate_image(path, degrees):
    """Повернуть изображение"""
    with Image.open(path) as img:
        rotated = img.rotate(degrees)
        rotated.save(path)

def image_colors(path, num_colors=10):
    """Получить основные цвета изображения"""
    with Image.open(path) as img:
        img = img.convert('RGB')
        pixels = list(img.getdata())
        color_counts = {}
        for pixel in pixels:
            if pixel in color_counts:
                color_counts[pixel] += 1
            else:
                color_counts[pixel] = 1
        sorted_colors = sorted(color_counts.items(), key=lambda x: x[1], reverse=True)
        return [color for color, _ in sorted_colors[:num_colors]]

# Функции для работы с аудио

def audio_info(path):
    """Получить информацию об аудиофайле"""
    try:
        with wave.open(path, 'rb') as wav:
            return {
                "channels": wav.getnchannels(),
                "sample_width": wav.getsampwidth(),
                "framerate": wav.getframerate(),
                "frames": wav.getnframes(),
                "duration": wav.getnframes() / wav.getframerate(),
            }
    except wave.Error:
        return None

def change_volume(input_path, output_path, volume_factor):
    """Изменить громкость аудио"""
    with wave.open(input_path, 'rb') as wav_in:
        params = wav_in.getparams()
        with wave.open(output_path, 'wb') as wav_out:
            wav_out.setparams(params)
            frames = wav_in.readframes(wav_in.getnframes())
            amplified = array.array('h', frames)
            for i in range(len(amplified)):
                amplified[i] = int(amplified[i] * volume_factor)
            wav_out.writeframes(amplified.tobytes())

# Общие функции для работы с медиафайлами

def media_type(path):
    """Определить тип медиафайла"""
    _, ext = os.path.splitext(path.lower())
    if ext in ['.webp', '.jpg', '.jpeg', '.png', '.gif', '.bmp', 'icon', 'ic']:
        return "image"
    elif ext in ['.wav', '.mp3', '.ogg', '.flac']:
        return "audio"
    elif ext in ['.mp4', '.avi', '.mov', '.mkv']:
        return "video"
    else:
        return "unknown"

def file_size(path):
    """Получить размер файла"""
    return os.path.getsize(path)

def rename_media_file(old_path, new_path):
    """Переименовать медиафайл"""
    os.rename(old_path, new_path)

def delete_media_file(path):
    """Удалить медиафайл"""
    os.remove(path)

def list_media_files(directory, media_type=None):
    """Получить список медиафайлов в директории"""
    all_files = os.listdir(directory)
    if media_type:
        return [f for f in all_files if get_media_type(os.path.join(directory, f)) == media_type]
    return all_files

# Дополнительные функции для работы с изображениями

def apply_grayscale(path):
    """Применить эффект оттенков серого к изображению"""
    with Image.open(path) as img:
        gray_img = img.convert('L')
        gray_img.save(path)

def crop_image(path, box):
    """Обрезать изображение"""
    with Image.open(path) as img:
        cropped_img = img.crop(box)
        cropped_img.save(path)

def flip_image(path, direction='horizontal'):
    """Отразить изображение"""
    with Image.open(path) as img:
        if direction == 'horizontal':
            flipped_img = img.transpose(Image.FLIP_LEFT_RIGHT)
        elif direction == 'vertical':
            flipped_img = img.transpose(Image.FLIP_TOP_BOTTOM)
        flipped_img.save(path)

# Дополнительные функции для работы с аудио

def reverse_audio(input_path, output_path):
    """Развернуть аудио"""
    with wave.open(input_path, 'rb') as wav_in:
        params = wav_in.getparams()
        frames = wav_in.readframes(wav_in.getnframes())
        reversed_frames = frames[::-1]
        with wave.open(output_path, 'wb') as wav_out:
            wav_out.setparams(params)
            wav_out.writeframes(reversed_frames)

def mix_audio(input_path1, input_path2, output_path):
    """Смешать два аудиофайла"""
    with wave.open(input_path1, 'rb') as wav1, wave.open(input_path2, 'rb') as wav2:
        if wav1.getnchannels() != wav2.getnchannels() or wav1.getsampwidth() != wav2.getsampwidth() or wav1.getframerate() != wav2.getframerate():
            raise ValueError("Audio files must have the same format")
        
        params = wav1.getparams()
        frames1 = wav1.readframes(wav1.getnframes())
        frames2 = wav2.readframes(wav2.getnframes())
        
        mixed_frames = array.array('h')
        for i in range(0, len(frames1), 2):
            mixed_frames.append((frames1[i] + frames2[i]) // 2)
            mixed_frames.append((frames1[i+1] + frames2[i+1]) // 2)
        
        with wave.open(output_path, 'wb') as wav_out:
            wav_out.setparams(params)
            wav_out.writeframes(mixed_frames.tobytes())
