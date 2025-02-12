""" шифрование""" 
def encrypt(data, key):
    # Шифрование
    data_bytes = data.encode()
    key_bytes = key.encode()
    mixed_bytes = bytearray(data_bytes) + bytearray(key_bytes)
    encrypted_bytes = bytearray()
    for i in range(len(mixed_bytes)):
        encrypted_bytes.append(mixed_bytes[i] ^ key_bytes[i % len(key_bytes)])
    return encrypted_bytes.hex()

""" дешифрование""" 
def decrypt(encrypted_data, key):
    # Дешифрование
    encrypted_bytes = bytearray.fromhex(encrypted_data)
    key_bytes = key.encode()
    decrypted_bytes = bytearray()
    for i in range(len(encrypted_bytes)):
        decrypted_bytes.append(encrypted_bytes[i] ^ key_bytes[i % len(key_bytes)])
    decrypted_data = decrypted_bytes.decode()
    return decrypted_data
