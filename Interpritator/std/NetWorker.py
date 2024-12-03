import urllib.request
import urllib.parse
import json
import socket
import http.client
import ssl
import email.utils
import time

def get_request(url, headers=None):
    """Выполняет GET-запрос к указанному URL."""
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req) as response:
        return response.read().decode('utf-8')

def post_request(url, data, headers=None):
    """Выполняет POST-запрос к указанному URL с заданными данными."""
    data = urllib.parse.urlencode(data).encode('ascii')
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req) as response:
        return response.read().decode('utf-8')

def download_file(url, filename):
    """Скачивает файл с указанного URL и сохраняет его локально."""
    urllib.request.urlretrieve(url, filename)

def parse_json(json_string):
    """Парсит JSON-строку и возвращает Python-объект."""
    return json.loads(json_string)

def encode_url_params(params):
    """Кодирует параметры для URL."""
    return urllib.parse.urlencode(params)

def get_ip_address(hostname):
    """Получает IP-адрес по имени хоста."""
    return socket.gethostbyname(hostname)

def get_hostname(ip_address):
    """Получает имя хоста по IP-адресу."""
    return socket.gethostbyaddr(ip_address)[0]

def check_port(host, port):
    """Проверяет, открыт ли указанный порт на хосте."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex((host, port))
    sock.close()
    return result == 0

def get_http_status(url):
    """Получает HTTP-статус указанного URL."""
    conn = http.client.HTTPSConnection(urllib.parse.urlparse(url).netloc)
    conn.request("HEAD", urllib.parse.urlparse(url).path)
    return conn.getresponse().status

def get_ssl_cert_info(hostname, port=443):
    """Получает информацию о SSL-сертификате сайта."""
    context = ssl.create_default_context()
    with socket.create_connection((hostname, port)) as sock:
        with context.wrap_socket(sock, server_hostname=hostname) as secure_sock:
            cert = secure_sock.getpeercert()
    return cert

def parse_http_date(http_date):
    """Парсит HTTP-дату и возвращает timestamp."""
    return time.mktime(email.utils.parsedate(http_date))

def create_basic_auth_header(username, password):
    """Создает заголовок для базовой HTTP-аутентификации."""
    auth = f"{username}:{password}"
    return {"Authorization": f"Basic {auth.encode('ascii').b64encode().decode('ascii')}"}

def get_redirect_url(url):
    """Получает URL, на который происходит редирект."""
    req = urllib.request.Request(url, method="HEAD")
    response = urllib.request.urlopen(req)
    return response.url if response.url != url else None

def is_url_accessible(url):
    """Проверяет, доступен ли URL."""
    try:
        urllib.request.urlopen(url)
        return True
    except urllib.error.URLError:
        return False

def get_content_type(url):
    """Получает тип контента по URL."""
    req = urllib.request.Request(url, method="HEAD")
    response = urllib.request.urlopen(req)
    return response.info().get_content_type()
