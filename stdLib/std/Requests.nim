## Requests - HTTP Client Library for RytonLang
## Python requests-like HTTP client with advanced features

import std/[httpclient, json, tables, sequtils, strutils, strformat, uri, times, base64]
import std/[asyncdispatch, asynchttpserver, net, os, math, sets, random, mimetypes]

# Экспортируем основные типы
export httpclient.HttpMethod, httpclient.HttpHeaders, httpclient.Response

type
  # Основные типы
  RequestsClient* = ref object
    client*: HttpClient
    baseUrl*: string
    defaultHeaders*: HttpHeaders
    timeout*: int
    retries*: int
    retryDelay*: int
    cookies*: Table[string, string]
    auth*: AuthInfo
    proxies*: ProxyInfo
    verify*: bool
    allowRedirects*: bool
    maxRedirects*: int
    backoffFactor*: float
    session*: bool

  # Информация об аутентификации
  AuthInfo* = object
    authType*: AuthType
    username*: string
    password*: string
    token*: string
    apiKey*: string

  AuthType* = enum
    authNone, authBasic, authBearer, authApiKey, authDigest

  # Информация о прокси
  ProxyInfo* = object
    http*: string
    https*: string
    username*: string
    password*: string

  # Результат запроса
  RequestResult* = object
    response*: Response
    statusCode*: int
    headers*: HttpHeaders
    body*: string
    json*: JsonNode
    cookies*: Table[string, string]
    url*: string
    elapsed*: float
    history*: seq[Response]

  # Конфигурация запроса
  RequestConfig* = object
    meth*: HttpMethod
    url*: string
    headers*: HttpHeaders
    params*: Table[string, string]
    data*: string
    json*: JsonNode
    files*: Table[string, string]
    auth*: AuthInfo
    timeout*: int
    allowRedirects*: bool
    verify*: bool
    stream*: bool

  # Исключения
  RequestException* = object of CatchableError
  ConnectionError* = object of RequestException
  TimeoutError* = object of RequestException
  HTTPError* = object of RequestException
  TooManyRedirects* = object of RequestException

# ============================================================================
# СОЗДАНИЕ И КОНФИГУРАЦИЯ КЛИЕНТА
# ============================================================================

proc newRequestsClient*(baseUrl: string = "", timeout: int = 30): RequestsClient =
  ## Создает новый HTTP клиент
  result = RequestsClient(
    client: newHttpClient(),
    baseUrl: baseUrl,
    defaultHeaders: newHttpHeaders(),
    timeout: timeout,
    cookies: initTable[string, string](),
    auth: AuthInfo(authType: authNone),
    proxies: ProxyInfo(),
    verify: true,
    allowRedirects: true,
    maxRedirects: 10,
    retries: 3,
    backoffFactor: 0.3,
    session: false
  )
  
  # Устанавливаем таймаут
  result.client.timeout = timeout * 1000

proc setBaseUrl*(client: RequestsClient, url: string) =
  ## Устанавливает базовый URL
  client.baseUrl = url

proc setDefaultHeaders*(client: RequestsClient, headers: HttpHeaders) =
  ## Устанавливает заголовки по умолчанию
  client.defaultHeaders = headers

proc addDefaultHeader*(client: RequestsClient, key, value: string) =
  ## Добавляет заголовок по умолчанию
  client.defaultHeaders[key] = value

proc setTimeout*(client: RequestsClient, timeout: int) =
  ## Устанавливает таймаут
  client.timeout = timeout
  client.client.timeout = timeout * 1000

proc setAuth*(client: RequestsClient, authType: AuthType, username: string = "", 
              password: string = "", token: string = "", apiKey: string = "") =
  ## Устанавливает аутентификацию
  client.auth = AuthInfo(
    authType: authType,
    username: username,
    password: password,
    token: token,
    apiKey: apiKey
  )

proc setProxy*(client: RequestsClient, http: string = "", https: string = "", 
               username: string = "", password: string = "") =
  ## Устанавливает прокси
  client.proxies = ProxyInfo(
    http: http,
    https: https,
    username: username,
    password: password
  )

proc setVerify*(client: RequestsClient, verify: bool) =
  ## Включает/выключает проверку SSL сертификатов
  client.verify = verify

proc setAllowRedirects*(client: RequestsClient, allow: bool, maxRedirects: int = 10) =
  ## Настраивает обработку редиректов
  client.allowRedirects = allow
  client.maxRedirects = maxRedirects

proc setRetries*(client: RequestsClient, retries: int, backoffFactor: float = 0.3) =
  ## Настраивает повторные попытки
  client.retries = retries
  client.backoffFactor = backoffFactor

# ============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================================

proc buildUrl(baseUrl: string, path: string, params: Table[string, string]): string =
  ## Строит полный URL с параметрами
  var url = if baseUrl.len > 0 and not path.startsWith("http"):
    baseUrl.strip(trailing = false, chars = {'/'}) & "/" & path.strip(leading = false, chars = {'/'})
  else:
    path
  
  if params.len > 0:
    var paramPairs: seq[string] = @[]
    for key, value in params:
      paramPairs.add(encodeUrl(key) & "=" & encodeUrl(value))
    url.add("?" & paramPairs.join("&"))
  
  result = url

proc applyAuth(client: RequestsClient, headers: var HttpHeaders) =
  ## Применяет аутентификацию к заголовкам
  case client.auth.authType
  of authBasic:
    let credentials = base64.encode(client.auth.username & ":" & client.auth.password)
    headers["Authorization"] = "Basic " & credentials
  of authBearer:
    headers["Authorization"] = "Bearer " & client.auth.token
  of authApiKey:
    headers["X-API-Key"] = client.auth.apiKey
  of authDigest:
    # Digest auth требует более сложной реализации
    discard
  of authNone:
    discard

proc mergeCookies(client: RequestsClient, response: Response): Table[string, string] =
  ## Объединяет куки из ответа с существующими
  result = client.cookies
  
  if response.headers.hasKey("Set-Cookie"):
    let setCookieHeader = response.headers["Set-Cookie"]
    for cookieLine in setCookieHeader.split(";"):
      let parts = cookieLine.split("=", 1)
      if parts.len == 2:
        let name = parts[0].strip()
        let value = parts[1].strip()
        result[name] = value
        client.cookies[name] = value

proc applyCookies(client: RequestsClient, headers: var HttpHeaders) =
  ## Применяет куки к заголовкам
  if client.cookies.len > 0:
    var cookieHeader: seq[string] = @[]
    for name, value in client.cookies:
      cookieHeader.add(name & "=" & value)
    headers["Cookie"] = cookieHeader.join("; ")

proc parseJsonSafely(body: string): JsonNode =
  ## Безопасно парсит JSON
  try:
    result = parseJson(body)
  except JsonParsingError:
    result = newJNull()

# ============================================================================
# ОСНОВНЫЕ HTTP МЕТОДЫ
# ============================================================================

proc request*(client: RequestsClient, config: RequestConfig): RequestResult =
  ## Основной метод выполнения HTTP запросов
  let startTime = cpuTime()
  var response: Response
  
  # Строим полный URL с параметрами
  let fullUrl = buildUrl(client.baseUrl, config.url, config.params)
  
  # Подготавливаем заголовки
  var headers = newHttpHeaders()
  
  # Добавляем заголовки по умолчанию
  if client.defaultHeaders != nil:
    for key, value in client.defaultHeaders:
      headers[key] = value
  
  # Добавляем заголовки из конфигурации
  if config.headers != nil:
    for key, value in config.headers:
      headers[key] = value
  
  # Подготавливаем тело запроса
  var body = ""
  if config.json != nil:
    body = $config.json
    headers["Content-Type"] = "application/json"
  elif config.data.len > 0:
    body = config.data
    if not headers.hasKey("Content-Type"):
      headers["Content-Type"] = "application/x-www-form-urlencoded"
  
  # Устанавливаем User-Agent если не задан
  if not headers.hasKey("User-Agent"):
    headers["User-Agent"] = "RytonRequests/1.0"
  
  # Выполняем запрос с повторными попытками
  for attempt in 0..<client.retries:
    try:
      case config.meth
      of HttpGet:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.get(fullUrl)
      
      of HttpPost:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.post(fullUrl, body)
      
      of HttpPut:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.put(fullUrl, body)
      
      of HttpDelete:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.delete(fullUrl)
      
      of HttpPatch:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.patch(fullUrl, body)
      
      of HttpHead:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.head(fullUrl)
      
      of HttpOptions:
        # HttpClient не имеет встроенного метода options, используем request
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.request(fullUrl, httpMethod = HttpOptions, body = body)
      
      else:
        if headers.len > 0:
          client.client.headers = headers
        response = client.client.request(fullUrl, httpMethod = config.meth, body = body)
      
      # Если запрос успешен, выходим из цикла повторов
      break
      
    except TimeoutError:
      if attempt == client.retries - 1:
        raise newException(TimeoutError, "Request timeout after " & $client.retries & " attempts")
      sleep(client.retryDelay * (attempt + 1))
      
    except OSError as e:
      if attempt == client.retries - 1:
        raise newException(ConnectionError, "Connection error: " & e.msg)
      sleep(client.retryDelay * (attempt + 1))
      
    except Exception as e:
      if attempt == client.retries - 1:
        raise newException(RequestException, "Request failed: " & e.msg)
      sleep(client.retryDelay * (attempt + 1))
  
  let elapsed = cpuTime() - startTime
  
  # Парсим cookies из ответа
  var cookies = initTable[string, string]()
  if response.headers.hasKey("Set-Cookie"):
    let cookieHeader = response.headers["Set-Cookie"]
    # Простой парсинг cookies (можно улучшить)
    for cookie in cookieHeader.split(";"):
      let parts = cookie.strip().split("=", 1)
      if parts.len == 2:
        cookies[parts[0]] = parts[1]
  
  # Обновляем cookies клиента
  for name, value in cookies:
    client.cookies[name] = value
  
  # Парсим JSON если возможно
  var jsonData: JsonNode = nil
  try:
    if response.headers.hasKey("Content-Type") and "application/json" in response.headers["Content-Type"]:
      jsonData = parseJson(response.body)
  except:
    jsonData = newJNull()
  
  # Создаем результат
  result = RequestResult(
    statusCode: response.code.int,
    headers: response.headers,
    body: response.body,
    json: jsonData,
    cookies: cookies,
    url: fullUrl,
    elapsed: elapsed
  )

# Альтернативная версия с более правильным использованием HttpClient

proc processResponse(response: Response, url: string, elapsed: float, client: RequestsClient): RequestResult =
  ## Обрабатывает ответ и создает RequestResult
  
  # Парсим cookies из ответа
  var cookies = initTable[string, string]()
  if response.headers.hasKey("Set-Cookie"):
    let cookieHeader = response.headers["Set-Cookie"]
    # Set-Cookie может содержать несколько значений, разделенных запятыми
    let cookieHeaders = cookieHeader.split(",")
    for singleCookie in cookieHeaders:
      # Простой парсинг cookies
      let parts = cookieHeader.split(";")[0].split("=", 1)
      if parts.len == 2:
        let name = parts[0].strip()
        let value = parts[1].strip()
        cookies[name] = value
        client.cookies[name] = value  # Обновляем cookies клиента
  
  # Парсим JSON если возможно
  var jsonData: JsonNode = newJNull()
  try:
    if response.headers.hasKey("Content-Type"):
      let contentType = $response.headers["Content-Type"]
      if "application/json" in contentType.toLower():
        if response.body.len > 0:
          jsonData = parseJson(response.body)
  except JsonParsingError:
    # Если JSON невалидный, оставляем null
    discard
  except:
    # Любые другие ошибки при парсинге JSON
    discard

  
  result = RequestResult(
    statusCode: response.code.int,
    headers: response.headers,
    body: response.body,
    json: jsonData,
    cookies: cookies,
    url: url,
    elapsed: elapsed
  )

proc requestAlternative*(client: RequestsClient, config: RequestConfig): RequestResult =
  ## Альтернативная реализация с правильным использованием HttpClient API
  let startTime = cpuTime()
  var response: Response
  
  # Строим полный URL с параметрами
  let fullUrl = buildUrl(client.baseUrl, config.url, config.params)
  
  # Подготавливаем заголовки
  var allHeaders = newHttpHeaders()
  
  # Добавляем заголовки по умолчанию
  if client.defaultHeaders != nil:
    for key, value in client.defaultHeaders:
      allHeaders[key] = value
  
  # Добавляем заголовки из конфигурации
  if config.headers != nil:
    for key, value in config.headers:
      allHeaders[key] = value
  
  # Подготавливаем тело запроса
  var body = ""
  if config.json != nil:
    body = $config.json
    allHeaders["Content-Type"] = "application/json"
  elif config.data.len > 0:
    body = config.data
    if not allHeaders.hasKey("Content-Type"):
      allHeaders["Content-Type"] = "application/x-www-form-urlencoded"
  
  # Устанавливаем заголовки в клиент
  client.client.headers = allHeaders
  
  # Выполняем запрос с повторными попытками
  for attempt in 0..<client.retries:
    try:
      case config.meth
      of HttpGet:
        response = client.client.get(fullUrl)
      of HttpPost:
        response = client.client.post(fullUrl, body)
      of HttpPut:
        response = client.client.put(fullUrl, body)
      of HttpDelete:
        response = client.client.delete(fullUrl)
      of HttpPatch:
        response = client.client.patch(fullUrl, body)
      of HttpHead:
        response = client.client.head(fullUrl)
      else:
        # Для других методов используем универсальный request
        response = client.client.request(fullUrl, httpMethod = config.meth, body = body)
      
      # Если запрос успешен, выходим из цикла
      break
      
    except TimeoutError:
      if attempt == client.retries - 1:
        raise newException(TimeoutError, fmt"Request timeout after {client.retries} attempts")
      sleep(client.retryDelay * (attempt + 1))
      
    except OSError as e:
      if attempt == client.retries - 1:
        raise newException(ConnectionError, fmt"Connection error: {e.msg}")
      sleep(client.retryDelay * (attempt + 1))
      
    except Exception as e:
      if attempt == client.retries - 1:
        raise newException(RequestException, fmt"Request failed: {e.msg}")
      sleep(client.retryDelay * (attempt + 1))
  
  let elapsed = cpuTime() - startTime
  
  # Обрабатываем ответ
  result = processResponse(response, fullUrl, elapsed, client)

proc get*(client: RequestsClient, url: string, params: Table[string, string] = initTable[string, string](),
          headers: HttpHeaders = nil): RequestResult =
  ## Выполняет GET запрос
  let config = RequestConfig(
    meth: HttpGet,
    url: url,
    params: params,
    headers: headers
  )
  result = client.request(config)

proc post*(client: RequestsClient, url: string, data: string = "", json: JsonNode = nil,
           headers: HttpHeaders = nil, params: Table[string, string] = initTable[string, string]()): RequestResult =
  ## Выполняет POST запрос
  let config = RequestConfig(
    meth: HttpPost,
    url: url,
    params: params,
    data: data,
    json: json,
    headers: headers
  )
  result = client.request(config)

proc put*(client: RequestsClient, url: string, data: string = "", json: JsonNode = nil,
          headers: HttpHeaders = nil, params: Table[string, string] = initTable[string, string]()): RequestResult =
  ## Выполняет PUT запрос
  let config = RequestConfig(
    meth: HttpPut,
    url: url,
    params: params,
    data: data,
    json: json,
    headers: headers
  )
  result = client.request(config)

proc delete*(client: RequestsClient, url: string, headers: HttpHeaders = nil,
             params: Table[string, string] = initTable[string, string]()): RequestResult =
  ## Выполняет DELETE запрос
  let config = RequestConfig(
    meth: HttpDelete,
    url: url,
    params: params,
    headers: headers
  )
  result = client.request(config)

proc patch*(client: RequestsClient, url: string, data: string = "", json: JsonNode = nil,
            headers: HttpHeaders = nil, params: Table[string, string] = initTable[string, string]()): RequestResult =
  ## Выполняет PATCH запрос
  let config = RequestConfig(
    meth: HttpPatch,
    url: url,
    params: params,
    data: data,
    json: json,
    headers: headers
  )
  result = client.request(config)

proc head*(client: RequestsClient, url: string, headers: HttpHeaders = nil,
           params: Table[string, string] = initTable[string, string]()): RequestResult =
  ## Выполняет HEAD запрос
  let config = RequestConfig(
    meth: HttpHead,
    url: url,
    params: params,
    headers: headers
  )
  result = client.request(config)

proc options*(client: RequestsClient, url: string, headers: HttpHeaders = nil,
              params: Table[string, string] = initTable[string, string]()): RequestResult =
  ## Выполняет OPTIONS запрос
  let config = RequestConfig(
    meth: HttpOptions,
    url: url,
    params: params,
    headers: headers
  )
  result = client.request(config)

# ============================================================================
# РАБОТА С ФАЙЛАМИ
# ============================================================================

proc uploadFile*(client: RequestsClient, url: string, filePath: string, 
                 fieldName: string = "file", additionalData: Table[string, string] = initTable[string, string](),
                 headers: HttpHeaders = nil): RequestResult =
  ## Загружает файл на сервер
  if not fileExists(filePath):
    raise newException(IOError, "File not found: " & filePath)
  
  let boundary = "----WebKitFormBoundary" & $getTime().toUnix()
  var body = ""
  
  # Добавляем дополнительные поля
  for key, value in additionalData:
    body.add("--" & boundary & "\r\n")
    body.add("Content-Disposition: form-data; name=\"" & key)

    body.add("\"\r\n\r\n")
    body.add(value & "\r\n")
  
  # Добавляем файл
  let fileName = extractFilename(filePath)
  let fileContent = readFile(filePath)
  let mimedb = newMimeTypes()
  let mimeType = mimedb.getMimetype(fileName.split('.')[^1])
  
  body.add("--" & boundary & "\r\n")
  body.add("Content-Disposition: form-data; name=\"" & fieldName & "\"; filename=\"" & fileName & "\"\r\n")
  body.add("Content-Type: " & mimeType & "\r\n\r\n")
  body.add(fileContent & "\r\n")
  body.add("--" & boundary & "--\r\n")
  
  # Устанавливаем заголовки
  var uploadHeaders = if headers != nil: headers else: newHttpHeaders()
  uploadHeaders["Content-Type"] = "multipart/form-data; boundary=" & boundary
  
  let config = RequestConfig(
    meth: HttpPost,
    url: url,
    data: body,
    headers: uploadHeaders
  )
  result = client.request(config)

proc downloadFile*(client: RequestsClient, url: string, savePath: string,
                   headers: HttpHeaders = nil, params: Table[string, string] = initTable[string, string]()): bool =
  ## Скачивает файл и сохраняет на диск
  try:
    let response = client.get(url, params, headers)
    if response.statusCode >= 200 and response.statusCode < 300:
      writeFile(savePath, response.body)
      return true
    else:
      return false
  except:
    return false

# ============================================================================
# СЕССИИ
# ============================================================================

proc createSession*(client: RequestsClient): RequestsClient =
  ## Создает сессию (копию клиента с общими куками)
  result = RequestsClient(
    client: newHttpClient(),
    baseUrl: client.baseUrl,
    defaultHeaders: client.defaultHeaders,
    timeout: client.timeout,
    cookies: client.cookies,
    auth: client.auth,
    proxies: client.proxies,
    verify: client.verify,
    allowRedirects: client.allowRedirects,
    maxRedirects: client.maxRedirects,
    retries: client.retries,
    backoffFactor: client.backoffFactor,
    session: true
  )
  result.client.timeout = client.timeout * 1000

proc closeSession*(client: RequestsClient) =
  ## Закрывает сессию
  if client.session:
    client.client.close()

# ============================================================================
# УТИЛИТЫ ДЛЯ РАБОТЫ С ОТВЕТАМИ
# ============================================================================

proc isSuccess*(requestResult: RequestResult): bool =
  ## Проверяет, успешен ли запрос (2xx статус)
  return requestResult.statusCode >= 200 and requestResult.statusCode < 300

proc isRedirect*(requestResult: RequestResult): bool =
  ## Проверяет, является ли ответ редиректом (3xx статус)
  return requestResult.statusCode >= 300 and requestResult.statusCode < 400

proc isClientError*(requestResult: RequestResult): bool =
  ## Проверяет, является ли ответ ошибкой клиента (4xx статус)
  return requestResult.statusCode >= 400 and requestResult.statusCode < 500

proc isServerError*(requestResult: RequestResult): bool =
  ## Проверяет, является ли ответ ошибкой сервера (5xx статус)
  return requestResult.statusCode >= 500

proc raiseForStatus*(requestResult: RequestResult) =
  ## Вызывает исключение для неуспешных статусов
  if requestResult.isClientError() or requestResult.isServerError():
    raise newException(HTTPError, fmt"HTTP {requestResult.statusCode} Error")

proc getHeader*(requestResult: RequestResult, name: string, default: string = ""): string =
  ## Получает значение заголовка
  if requestResult.headers.hasKey(name):
    return requestResult.headers[name]
  else:
    return default

proc getCookie*(requestResult: RequestResult, name: string, default: string = ""): string =
  ## Получает значение куки
  if requestResult.cookies.hasKey(name):
    requestResult.cookies[name]
  else:
    return default

proc saveToFile*(requestResult: RequestResult, filePath: string): bool =
  ## Сохраняет тело ответа в файл
  try:
    writeFile(filePath, requestResult.body)
    return true
  except:
    return false

# ============================================================================
# СПЕЦИАЛЬНЫЕ МЕТОДЫ
# ============================================================================

proc jsonRequest*(client: RequestsClient, meth: HttpMethod, url: string, 
                  data: JsonNode, headers: HttpHeaders = nil): RequestResult =
  ## Удобный метод для JSON запросов
  var jsonHeaders = if headers != nil: headers else: newHttpHeaders()
  jsonHeaders["Content-Type"] = "application/json"
  jsonHeaders["Accept"] = "application/json"
  
  let config = RequestConfig(
    meth: meth,
    url: url,
    json: data,
    headers: jsonHeaders
  )
  result = client.request(config)

proc formRequest*(client: RequestsClient, meth: HttpMethod, url: string,
                  formData: Table[string, string], headers: HttpHeaders = nil): RequestResult =
  ## Удобный метод для form-data запросов
  var formHeaders = if headers != nil: headers else: newHttpHeaders()
  formHeaders["Content-Type"] = "application/x-www-form-urlencoded"
  
  var body = ""
  var first = true
  for key, value in formData:
    if not first: body.add("&")
    body.add(encodeUrl(key) & "=" & encodeUrl(value))
    first = false
  
  let config = RequestConfig(
    meth: meth,
    url: url,
    data: body,
    headers: formHeaders
  )
  result = client.request(config)

proc apiRequest*(client: RequestsClient, endpoint: string, apiKey: string,
                 meth: HttpMethod = HttpGet, data: JsonNode = nil): RequestResult =
  ## Удобный метод для API запросов
  var apiHeaders = newHttpHeaders()
  apiHeaders["Authorization"] = "Bearer " & apiKey
  apiHeaders["Content-Type"] = "application/json"
  apiHeaders["Accept"] = "application/json"
  
  let config = RequestConfig(
    meth: meth,
    url: endpoint,
    json: data,
    headers: apiHeaders
  )
  result = client.request(config)

# ============================================================================
# ПАКЕТНЫЕ ЗАПРОСЫ
# ============================================================================

proc batchRequests*(client: RequestsClient, configs: seq[RequestConfig]): seq[RequestResult] =
  ## Выполняет несколько запросов последовательно
  result = newSeq[RequestResult](configs.len)
  for i, config in configs:
    result[i] = client.request(config)

# ============================================================================
# КЭШИРОВАНИЕ
# ============================================================================

type
  CacheEntry = object
    response: RequestResult
    timestamp: float
    ttl: float

var requestCache = initTable[string, CacheEntry]()

proc getCacheKey(meth: HttpMethod, url: string, params: Table[string, string]): string =
  ## Генерирует ключ для кэша
  result = $meth & ":" & url
  if params.len > 0:
    var paramPairs: seq[string] = @[]
    for key, value in params:
      paramPairs.add(key & "=" & value)
    result.add("?" & paramPairs.join("&"))

proc cachedRequest*(client: RequestsClient, config: RequestConfig, ttl: float = 300.0): RequestResult =
  ## Выполняет запрос с кэшированием
  let cacheKey = getCacheKey(config.meth, config.url, config.params)
  let now = cpuTime()
  
  # Проверяем кэш
  if requestCache.hasKey(cacheKey):
    let entry = requestCache[cacheKey]
    if now - entry.timestamp < entry.ttl:
      return entry.response
  
  # Выполняем запрос
  result = client.request(config)
  
  # Сохраняем в кэш только успешные GET запросы
  if config.meth == HttpGet and result.isSuccess():
    requestCache[cacheKey] = CacheEntry(
      response: result,
      timestamp: now,
      ttl: ttl
    )

proc clearCache*() =
  ## Очищает кэш запросов
  requestCache.clear()

# ============================================================================
# ГЛОБАЛЬНЫЕ ФУНКЦИИ ДЛЯ УДОБСТВА
# ============================================================================

var globalClient* = newRequestsClient()

proc get*(url: string, params: Table[string, string] = initTable[string, string](),
          headers: HttpHeaders = nil): RequestResult =
  globalClient.get(url, params, headers)

proc post*(url: string, data: string = "", json: JsonNode = nil,
           headers: HttpHeaders = nil): RequestResult =
  globalClient.post(url, data, json, headers)

proc put*(url: string, data: string = "", json: JsonNode = nil,
          headers: HttpHeaders = nil): RequestResult =
  globalClient.put(url, data, json, headers)

proc delete*(url: string, headers: HttpHeaders = nil): RequestResult =
  globalClient.delete(url, headers)

proc patch*(url: string, data: string = "", json: JsonNode = nil,
            headers: HttpHeaders = nil): RequestResult =
  globalClient.patch(url, data, json, headers)

proc head*(url: string, headers: HttpHeaders = nil): RequestResult =
  globalClient.head(url, headers)

proc options*(url: string, headers: HttpHeaders = nil): RequestResult =
  globalClient.options(url, headers)

# ============================================================================
# СПЕЦИАЛЬНЫЕ УТИЛИТЫ
# ============================================================================

proc buildApiUrl*(baseUrl: string, version: string, endpoint: string): string =
  ## Строит URL для API
  result = baseUrl.strip(trailing = false, chars = {'/'}) & 
           "/api/" & version & "/" & 
           endpoint.strip(leading = false, chars = {'/'})

proc parseBasicAuth*(authHeader: string): tuple[username, password: string] =
  ## Парсит Basic Auth заголовок
  if authHeader.startsWith("Basic "):
    let encoded = authHeader[6..^1]
    let decoded = base64.decode(encoded)
    let parts = decoded.split(":", 1)
    if parts.len == 2:
      result = (username: parts[0], password: parts[1])

proc createFormData*(data: Table[string, string]): string =
  ## Создает form-data строку
  var pairs: seq[string] = @[]
  for key, value in data:
    pairs.add(encodeUrl(key) & "=" & encodeUrl(value))
  result = pairs.join("&")

proc parseQueryString*(query: string): Table[string, string] =
  ## Парсит query string в таблицу
  result = initTable[string, string]()
  if query.len == 0: return
  
  let cleanQuery = if query.startsWith("?"): query[1..^1] else: query
  for pair in cleanQuery.split("&"):
    let parts = pair.split("=", 1)
    if parts.len == 2:
      result[decodeUrl(parts[0])] = decodeUrl(parts[1])

proc createMultipartData*(data: Table[string, string], files: Table[string, string] = initTable[string, string]()): tuple[body: string, contentType: string] =
  ## Создает multipart/form-data
  let boundary = "----WebKitFormBoundary" & $getTime().toUnix()
  var body = ""
  
  # Добавляем текстовые поля
  for key, value in data:
    body.add("--" & boundary & "\r\n")
    body.add("Content-Disposition: form-data; name=\"" & key & "\"\r\n\r\n")
    body.add(value & "\r\n")
  
  # Добавляем файлы
  for fieldName, filePath in files:
    if fileExists(filePath):
      let fileName = extractFilename(filePath)
      let fileContent = readFile(filePath)
      let mimedb = newMimeTypes()
      let mimeType = mimedb.getMimetype(fileName.split('.')[^1])
      
      body.add("--" & boundary & "\r\n")
      body.add("Content-Disposition: form-data; name=\"" & fieldName & "\"; filename=\"" & fileName & "\"\r\n")
      body.add("Content-Type: " & mimeType & "\r\n\r\n")
      body.add(fileContent & "\r\n")
  
  body.add("--" & boundary & "--\r\n")
  
  result = (
    body: body,
    contentType: "multipart/form-data; boundary=" & boundary
  )

# ============================================================================
# МОНИТОРИНГ И ЛОГИРОВАНИЕ
# ============================================================================

type
  RequestLogger* = ref object
    logRequests*: bool
    logResponses*: bool
    logErrors*: bool
    logFile*: string

var logger* = RequestLogger(
  logRequests: false,
  logResponses: false,
  logErrors: true,
  logFile: ""
)

proc enableLogging*(logRequests: bool = true, logResponses: bool = true, 
                   logErrors: bool = true, logFile: string = "") =
  ## Включает логирование запросов
  logger.logRequests = logRequests
  logger.logResponses = logResponses
  logger.logErrors = logErrors
  logger.logFile = logFile

proc logRequest(config: RequestConfig) =
  ## Логирует запрос
  if not logger.logRequests: return
  
  let logMsg = fmt"[REQUEST] {config.meth} {config.url}"
  if logger.logFile.len > 0:
    let file = open(logger.logFile, fmAppend)
    file.writeLine(fmt"{now()} {logMsg}")
    file.close()
  else:
    echo logMsg

proc logResponse(result: RequestResult) =
  ## Логирует ответ
  if not logger.logResponses: return
  
  let logMsg = fmt"[RESPONSE] {result.statusCode} {result.url} ({result.elapsed:.3f}s)"
  if logger.logFile.len > 0:
    let file = open(logger.logFile, fmAppend)
    file.writeLine(fmt"{now()} {logMsg}")
    file.close()
  else:
    echo logMsg

proc logError(error: string, url: string) =
  ## Логирует ошибку
  if not logger.logErrors: return
  
  let logMsg = fmt"[ERROR] {url}: {error}"
  if logger.logFile.len > 0:
    let file = open(logger.logFile, fmAppend)
    file.writeLine(fmt"{now()} {logMsg}")
    file.close()
  else:
    echo logMsg

# ============================================================================
# МЕТРИКИ И СТАТИСТИКА
# ============================================================================

type
  RequestMetrics* = object
    totalRequests*: int
    successfulRequests*: int
    failedRequests*: int
    totalTime*: float
    averageTime*: float
    minTime*: float
    maxTime*: float
    statusCodes*: Table[int, int]

var metrics* = RequestMetrics(
  statusCodes: initTable[int, int]()
)

proc updateMetrics(result: RequestResult, success: bool) =
  ## Обновляет метрики запросов
  inc metrics.totalRequests
  
  if success:
    inc metrics.successfulRequests
  else:
    inc metrics.failedRequests
  
  metrics.totalTime += result.elapsed
  metrics.averageTime = metrics.totalTime / float(metrics.totalRequests)
  
  if metrics.minTime == 0.0 or result.elapsed < metrics.minTime:
    metrics.minTime = result.elapsed
  
  if result.elapsed > metrics.maxTime:
    metrics.maxTime = result.elapsed
  
  # Обновляем статистику по статус кодам
  if metrics.statusCodes.hasKey(result.statusCode):
    inc metrics.statusCodes[result.statusCode]
  else:
    metrics.statusCodes[result.statusCode] = 1

proc getMetrics*(): RequestMetrics =
  ## Возвращает текущие метрики
  result = metrics

proc resetMetrics*() =
  ## Сбрасывает метрики
  metrics = RequestMetrics(
    statusCodes: initTable[int, int]()
  )

proc printMetrics*() =
  ## Выводит метрики в консоль
  echo "=== Request Metrics ==="
  echo fmt"Total requests: {metrics.totalRequests}"
  echo fmt"Successful: {metrics.successfulRequests}"
  echo fmt"Failed: {metrics.failedRequests}"
  echo fmt"Success rate: {(metrics.successfulRequests * 100 / max(1, metrics.totalRequests)):.1f}%"
  echo fmt"Average time: {metrics.averageTime:.3f}s"
  echo fmt"Min time: {metrics.minTime:.3f}s"
  echo fmt"Max time: {metrics.maxTime:.3f}s"
  echo "Status codes:"
  for code, count in metrics.statusCodes:
    echo fmt"  {code}: {count}"

# ============================================================================
# РАСШИРЕННЫЕ ФУНКЦИИ
# ============================================================================

const
  ServerErrorCodes* = [500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511]
  ClientErrorCodes* = [400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 421, 422, 423, 424, 425, 426, 428, 429, 431, 451]
  RedirectCodes* = [300, 301, 302, 303, 304, 305, 306, 307, 308]

proc createRetrySet*(codes: openArray[int]): HashSet[int] =
  ## Создает HashSet из массива статус-кодов
  result = initHashSet[int]()
  for code in codes:
    result.incl(code)

proc createRetryRange*(start: int, finish: int): HashSet[int] =
  ## Создает HashSet из диапазона статус-кодов
  result = initHashSet[int]()
  for code in start..finish:
    result.incl(code)

# Предопределенные наборы для удобства
let 
  ServerErrors* = createRetrySet(ServerErrorCodes)
  ClientErrors* = createRetrySet(ClientErrorCodes)
  RedirectErrors* = createRetrySet(RedirectCodes)
  AllErrors* = ServerErrors + ClientErrors + RedirectErrors

# Улучшенная версия с более гибкими настройками
type
  RetryConfig* = object
    maxRetries*: int
    baseDelay*: int           # Базовая задержка в миллисекундах
    maxDelay*: int            # Максимальная задержка
    backoffMultiplier*: float # Множитель для экспоненциальной задержки
    jitter*: bool             # Добавлять случайную задержку
    retryOn*: HashSet[int]    # Статус-коды для повтора
    retryOnExceptions*: bool  # Повторять при исключениях

proc newRetryConfig*(maxRetries: int = 3, baseDelay: int = 1000,
                    maxDelay: int = 30000, backoffMultiplier: float = 2.0,
                    jitter: bool = true, retryOn: HashSet[int] = ServerErrors,
                    retryOnExceptions: bool = true): RetryConfig =
  ## Создает конфигурацию для повторных попыток
  result = RetryConfig(
    maxRetries: maxRetries,
    baseDelay: baseDelay,
    maxDelay: maxDelay,
    backoffMultiplier: backoffMultiplier,
    jitter: jitter,
    retryOn: retryOn,
    retryOnExceptions: retryOnExceptions
  )

proc calculateDelay(config: RetryConfig, attempt: int): int =
  ## Вычисляет задержку для попытки
  var delay = float(config.baseDelay) * pow(config.backoffMultiplier, float(attempt))
  delay = min(delay, float(config.maxDelay))
  
  if config.jitter:
    # Добавляем случайную задержку ±25%
    let jitterRange = delay * 0.25
    let randomOffset = (rand(2.0) - 1.0) * jitterRange  # -jitterRange до +jitterRange
    delay += randomOffset
  
  return max(0, int(delay))

proc requestWithAdvancedRetry*(client: RequestsClient, config: RequestConfig,
                              retryConfig: RetryConfig): RequestResult =
  ## Выполняет запрос с продвинутой логикой повторов
  var lastResult: RequestResult
  var lastException: ref Exception = nil
  
  for attempt in 0..retryConfig.maxRetries:
    try:
      lastResult = client.request(config)
      
      # Если статус-код не требует повтора, возвращаем результат
      if lastResult.statusCode notin retryConfig.retryOn:
        return lastResult
      
      # Если это последняя попытка, возвращаем результат
      if attempt == retryConfig.maxRetries:
        return lastResult
      
      # Ждем перед следующей попыткой
      let delay = calculateDelay(retryConfig, attempt)
      sleep(delay)
      
    except Exception as e:
      lastException = e
      
      # Если не нужно повторять при исключениях, пробрасываем ошибку
      if not retryConfig.retryOnExceptions:
        raise e
      
      # Если это последняя попытка, пробрасываем ошибку
      if attempt == retryConfig.maxRetries:
        raise e
      
      # Ждем перед следующей попыткой
      let delay = calculateDelay(retryConfig, attempt)
      sleep(delay)
  
  # Если дошли сюда, значит все попытки исчерпаны
  if lastException != nil:
    raise lastException
  else:
    return lastResult

# Удобные функции с предустановленными конфигурациями
proc requestWithServerErrorRetry*(client: RequestsClient, config: RequestConfig,
                                 maxRetries: int = 3): RequestResult =
  ## Повторяет запрос только при серверных ошибках (5xx)
  let retryConfig = newRetryConfig(
    maxRetries = maxRetries,
    retryOn = ServerErrors
  )
  result = client.requestWithAdvancedRetry(config, retryConfig)

proc requestWithNetworkRetry*(client: RequestsClient, config: RequestConfig,
                             maxRetries: int = 5): RequestResult =
  ## Повторяет запрос при сетевых ошибках и таймаутах
  let retryConfig = newRetryConfig(
    maxRetries = maxRetries,
    baseDelay = 500,
    retryOn = createRetrySet([502, 503, 504, 408, 429]),  # Bad Gateway, Service Unavailable, Gateway Timeout, Request Timeout, Too Many Requests
    retryOnExceptions = true
  )
  result = client.requestWithAdvancedRetry(config, retryConfig)

proc requestWithAggressiveRetry*(client: RequestsClient, config: RequestConfig,
                                maxRetries: int = 10): RequestResult =
  ## Агрессивные повторы для критически важных запросов
  let retryConfig = newRetryConfig(
    maxRetries = maxRetries,
    baseDelay = 100,
    maxDelay = 10000,
    backoffMultiplier = 1.5,
    retryOn = ServerErrors + createRetrySet([408, 429, 502, 503, 504]),
    retryOnExceptions = true
  )
  result = client.requestWithAdvancedRetry(config, retryConfig)

# Глобальные функции для удобства
proc getWithRetry*(url: string, maxRetries: int = 3,
                  params: Table[string, string] = initTable[string, string](),
                  headers: HttpHeaders = nil): RequestResult =
  ## GET запрос с повторными попытками
  let config = RequestConfig(
    meth: HttpGet,
    url: url,
    params: params,
    headers: headers
  )
  result = globalClient.requestWithServerErrorRetry(config, maxRetries)

proc postWithRetry*(url: string, maxRetries: int = 3,
                   data: string = "", json: JsonNode = nil,
                   headers: HttpHeaders = nil): RequestResult =
  ## POST запрос с повторными попытками
  let config = RequestConfig(
    meth: HttpPost,
    url: url,
    data: data,
    json: json,
    headers: headers
  )
  result = globalClient.requestWithServerErrorRetry(config, maxRetries)

# Статистика повторных попыток
type
  RetryStats* = object
    totalAttempts*: int
    successfulRetries*: int
    failedRetries*: int
    averageAttempts*: float

var retryStats* = RetryStats()

proc updateRetryStats(attempts: int, success: bool) =
  ## Обновляет статистику повторных попыток
  inc retryStats.totalAttempts
  if success and attempts > 1:
    inc retryStats.successfulRetries
  elif not success:
    inc retryStats.failedRetries
  
  retryStats.averageAttempts = float(retryStats.totalAttempts) / float(max(1, retryStats.successfulRetries + retryStats.failedRetries))

proc getRetryStats*(): RetryStats =
  ## Возвращает статистику повторных попыток
  result = retryStats

proc resetRetryStats*() =
  ## Сбрасывает статистику повторных попыток
  retryStats = RetryStats()

proc printRetryStats*() =
  ## Выводит статистику повторных попыток
  echo "=== Retry Statistics ==="
  echo fmt"Total attempts: {retryStats.totalAttempts}"
  echo fmt"Successful retries: {retryStats.successfulRetries}"
  echo fmt"Failed retries: {retryStats.failedRetries}"
  echo fmt"Average attempts: {retryStats.averageAttempts:.2f}"

proc requestWithCircuitBreaker*(client: RequestsClient, config: RequestConfig,
                               failureThreshold: int = 5, timeout: int = 60000): RequestResult =
  ## Выполняет запрос с circuit breaker паттерном
  # Упрощенная реализация circuit breaker
  # В реальном проекте стоит использовать более сложную логику

  var failures = 0
  var lastFailureTime = 0.0
  
  let now = cpuTime()
  
  # Проверяем, не открыт ли circuit breaker
  if failures >= failureThreshold:
    if (now - lastFailureTime) * 1000 < float(timeout):
      raise newException(ConnectionError, "Circuit breaker is open")
    else:
      failures = 0  # Сбрасываем счетчик после таймаута
  
  try:
    result = client.request(config)
    if result.isSuccess():
      failures = 0  # Сбрасываем счетчик при успехе
    else:
      inc failures
      lastFailureTime = now
  except:
    inc failures
    lastFailureTime = now
    raise

proc requestWithRateLimit*(client: RequestsClient, config: RequestConfig,
                          requestsPerSecond: float): RequestResult =
  ## Выполняет запрос с ограничением скорости
  var lastRequestTime = 0.0
  
  let now = cpuTime()
  let minInterval = 1.0 / requestsPerSecond
  let timeSinceLastRequest = now - lastRequestTime
  
  if timeSinceLastRequest < minInterval:
    let sleepTime = int((minInterval - timeSinceLastRequest) * 1000)
    sleep(sleepTime)
  
  lastRequestTime = cpuTime()
  result = client.request(config)

# ============================================================================
# ТЕСТИРОВАНИЕ И МОКИРОВАНИЕ
# ============================================================================

type
  MockResponse* = object
    statusCode*: int
    headers*: HttpHeaders
    body*: string
    delay*: int

  MockRule* = object
    meth*: HttpMethod
    urlPattern*: string
    response*: MockResponse

var mockRules*: seq[MockRule] = @[]
var mockingEnabled* = false

proc enableMocking*() =
  ## Включает режим мокирования
  mockingEnabled = true

proc disableMocking*() =
  ## Выключает режим мокирования
  mockingEnabled = false

proc addMockRule*(meth: HttpMethod, urlPattern: string, statusCode: int,
                 body: string = "", headers: HttpHeaders = nil, delay: int = 0) =
  ## Добавляет правило мокирования
  let mockHeaders = if headers != nil: headers else: newHttpHeaders()
  
  mockRules.add(MockRule(
    meth: meth,
    urlPattern: urlPattern,
    response: MockResponse(
      statusCode: statusCode,
      headers: mockHeaders,
      body: body,
      delay: delay
    )
  ))

proc clearMockRules*() =
  ## Очищает все правила мокирования
  mockRules.setLen(0)

proc findMockRule(meth: HttpMethod, url: string): MockRule =
  ## Находит подходящее правило мокирования
  for rule in mockRules:
    if rule.meth == meth and url.contains(rule.urlPattern):
      return rule
  
  # Возвращаем правило по умолчанию
  result = MockRule(
    meth: meth,
    urlPattern: "",
    response: MockResponse(
      statusCode: 404,
      headers: newHttpHeaders(),
      body: "Mock not found",
      delay: 0
    )
  )

# ============================================================================
# ОБНОВЛЕННЫЙ ОСНОВНОЙ МЕТОД REQUEST С ДОПОЛНИТЕЛЬНЫМИ ФУНКЦИЯМИ
# ============================================================================

proc requestAdvanced*(client: RequestsClient, config: RequestConfig): RequestResult =
  ## Расширенный метод выполнения запросов с логированием, метриками и мокированием
  
  # Логируем запрос
  logRequest(config)
  
  # Проверяем мокирование
  if mockingEnabled:
    let mockRule = findMockRule(config.meth, config.url)
    if mockRule.urlPattern.len > 0 or config.url.contains(mockRule.urlPattern):
      if mockRule.response.delay > 0:
        sleep(mockRule.response.delay)
      
      result = RequestResult(
        statusCode: mockRule.response.statusCode,
        headers: mockRule.response.headers,
        body: mockRule.response.body,
        json: parseJsonSafely(mockRule.response.body),
        url: config.url,
        elapsed: float(mockRule.response.delay) / 1000.0
      )
      
      logResponse(result)
      updateMetrics(result, result.isSuccess())
      return result
  
  # Выполняем реальный запрос
  try:
    result = client.request(config)
    logResponse(result)
    updateMetrics(result, result.isSuccess())
  except Exception as e:
    logError(e.msg, config.url)
    updateMetrics(RequestResult(url: config.url, elapsed: 0.0), false)
    raise

# ============================================================================
# СПЕЦИАЛИЗИРОВАННЫЕ КЛИЕНТЫ
# ============================================================================

proc newRestApiClient*(baseUrl: string, apiKey: string, version: string = "v1"): RequestsClient =
  ## Создает клиент для REST API
  result = newRequestsClient(baseUrl)
  result.addDefaultHeader("Authorization", "Bearer " & apiKey)
  result.addDefaultHeader("Content-Type", "application/json")
  result.addDefaultHeader("Accept", "application/json")
  result.addDefaultHeader("User-Agent", "RytonRequests/1.0")
  result.baseUrl = buildApiUrl(baseUrl, version, "")

proc newGraphQLClient*(endpoint: string, token: string = ""): RequestsClient =
  ## Создает клиент для GraphQL
  result = newRequestsClient(endpoint)
  result.addDefaultHeader("Content-Type", "application/json")
  result.addDefaultHeader("Accept", "application/json")
  if token.len > 0:
    result.addDefaultHeader("Authorization", "Bearer " & token)

proc graphqlQuery*(client: RequestsClient, query: string, variables: JsonNode = nil): RequestResult =
  ## Выполняет GraphQL запрос
  var requestData = %*{"query": query}
  if variables != nil:
    requestData["variables"] = variables
  
  result = client.post("", json = requestData)

proc newWebhookClient*(secret: string = ""): RequestsClient =
  ## Создает клиент для отправки вебхуков
  result = newRequestsClient()
  result.addDefaultHeader("Content-Type", "application/json")
  result.addDefaultHeader("User-Agent", "RytonWebhook/1.0")
  if secret.len > 0:
    result.addDefaultHeader("X-Webhook-Secret", secret)

# ============================================================================
# УТИЛИТЫ ДЛЯ РАБОТЫ С JSON API
# ============================================================================

proc jsonApiGet*[T](client: RequestsClient, url: string, responseType: typedesc[T]): T =
  ## Выполняет GET запрос и десериализует JSON ответ
  let response = client.get(url)
  response.raiseForStatus()
  result = response.json.to(T)

proc jsonApiPost*[T, U](client: RequestsClient, url: string, data: T, responseType: typedesc[U]): U =
  ## Выполняет POST запрос с JSON данными и десериализует ответ
  let response = client.post(url, json = %data)
  response.raiseForStatus()
  result = response.json.to(U)

# ============================================================================
# ГЛОБАЛЬНЫЕ НАСТРОЙКИ
# ============================================================================

proc setGlobalTimeout*(timeout: int) =
  ## Устанавливает глобальный таймаут
  globalClient.setTimeout(timeout)

proc setGlobalUserAgent*(userAgent: string) =
  ## Устанавливает глобальный User-Agent
  globalClient.addDefaultHeader("User-Agent", userAgent)

proc setGlobalAuth*(authType: AuthType, username: string = "", 
                   password: string = "", token: string = "", apiKey: string = "") =
  ## Устанавливает глобальную аутентификацию
  globalClient.setAuth(authType, username, password, token, apiKey)

proc setGlobalProxy*(http: string = "", https: string = "", 
                    username: string = "", password: string = "") =
  ## Устанавливает глобальный прокси
  globalClient.setProxy(http, https, username, password)

# ============================================================================
# СПЕЦИАЛЬНЫЕ УТИЛИТЫ ДЛЯ РАЗРАБОТЧИКОВ
# ============================================================================

proc debugRequest*(config: RequestConfig): string =
  ## Возвращает отладочную информацию о запросе
  result = fmt"=== DEBUG REQUEST ===" & "\n"
  result.add(fmt"Method: {config.meth}" & "\n")
  result.add(fmt"URL: {config.url}" & "\n")
  
  if config.headers != nil:
    result.add("Headers:" & "\n")
    for key, value in config.headers:
      result.add(fmt"  {key}: {value}" & "\n")
  
  if config.params.len > 0:
    result.add("Parameters:" & "\n")
    for key, value in config.params:
      result.add(fmt"  {key}: {value}" & "\n")
  
  if config.data.len > 0:
    result.add(fmt"Body: {config.data}" & "\n")
  
  if config.json != nil:
    result.add(fmt"JSON: {config.json}" & "\n")

proc debugResponse*(requestResult: RequestResult): string =
  ## Возвращает отладочную информацию об ответе
  result = fmt"=== DEBUG RESPONSE ===" & "\n"
  result.add(fmt"Status: {requestResult.statusCode}" & "\n")
  result.add(fmt"URL: {requestResult.url}" & "\n")
  result.add(fmt"Elapsed: {requestResult.elapsed:.3f}s" & "\n")
  
  result.add("Headers:" & "\n")
  for key, value in requestResult.headers:
    result.add(fmt"  {key}: {value}" & "\n")
  
  if requestResult.cookies.len > 0:
    result.add("Cookies:" & "\n")
    for key, value in requestResult.cookies:
      result.add(fmt"  {key}: {value}" & "\n")
  
  result.add(fmt"Body length: {requestResult.body.len} bytes" & "\n")
  
  if requestResult.json.kind != JNull:
    result.add("JSON response: Yes" & "\n")

proc curlCommand*(config: RequestConfig): string =
  ## Генерирует эквивалентную curl команду
  result = "curl"
  
  # Метод
  if config.meth != HttpGet:
    result.add(fmt" -X {config.meth}")
  
  # Заголовки
  if config.headers != nil:
    for key, value in config.headers:
      result.add(" -H \"" & key & ":" & value & "\"")
  
  # Данные
  if config.data.len > 0:
    result.add(fmt" -d '{config.data}'")
  elif config.json != nil:
    result.add(fmt" -d '{config.json}'")
  
  # URL с параметрами
  let url = buildUrl("", config.url, config.params)
  result.add("\"" & url & "\"")

# ============================================================================
# РАБОТА С COOKIES
# ============================================================================

proc saveCookiesToFile*(client: RequestsClient, filePath: string): bool =
  ## Сохраняет куки в файл
  try:
    var cookieLines: seq[string] = @[]
    for name, value in client.cookies:
      cookieLines.add(fmt"{name}={value}")
    writeFile(filePath, cookieLines.join("\n"))
    return true
  except:
    return false

proc loadCookiesFromFile*(client: RequestsClient, filePath: string): bool =
  ## Загружает куки из файла
  try:
    if not fileExists(filePath):
      return false
    
    let content = readFile(filePath)
    for line in content.splitLines():
      if line.len > 0 and "=" in line:
        let parts = line.split("=", 1)
        if parts.len == 2:
          client.cookies[parts[0]] = parts[1]
    return true
  except:
    return false

proc clearCookies*(client: RequestsClient) =
  ## Очищает все куки
  client.cookies.clear()

# ============================================================================
# РАБОТА С СЕРТИФИКАТАМИ
# ============================================================================

proc setCertificate*(client: RequestsClient, certFile: string, keyFile: string = "") =
  ## Устанавливает клиентский сертификат
  # В реальной реализации здесь была бы настройка SSL контекста
  discard

proc setCACertificate*(client: RequestsClient, caFile: string) =
  ## Устанавливает CA сертификат
  # В реальной реализации здесь была бы настройка SSL контекста
  discard

# ============================================================================
# STREAMING И CHUNKED TRANSFER
# ============================================================================

proc streamRequest*(client: RequestsClient, config: RequestConfig, 
                   chunkCallback: proc(chunk: string)) =
  ## Выполняет запрос с потоковой обработкой ответа
  # Упрощенная реализация
  let response = client.request(config)
  
  # В реальной реализации здесь была бы потоковая обработка
  const chunkSize = 8192
  var pos = 0
  while pos < response.body.len:
    let endPos = min(pos + chunkSize, response.body.len)
    let chunk = response.body[pos..<endPos]
    chunkCallback(chunk)
    pos = endPos

proc downloadWithProgress*(client: RequestsClient, url: string, savePath: string,
                          progressCallback: proc(downloaded, total: int)) =
  ## Скачивает файл с отображением прогресса
  let response = client.get(url)
  if not response.isSuccess():
    raise newException(HTTPError, fmt"Download failed: {response.statusCode}")
  
  let totalSize = response.body.len
  var downloaded = 0
  
  let file = open(savePath, fmWrite)
  defer: file.close()
  
  const chunkSize = 8192
  var pos = 0
  while pos < response.body.len:
    let endPos = min(pos + chunkSize, response.body.len)
    let chunk = response.body[pos..<endPos]
    file.write(chunk)
    downloaded += chunk.len
    progressCallback(downloaded, totalSize)
    pos = endPos

# ============================================================================
# РАБОТА С WEBSOCKETS (базовая поддержка)
# ============================================================================

proc upgradeToWebSocket*(client: RequestsClient, url: string): bool =
  ## Пытается обновить соединение до WebSocket
  var headers = newHttpHeaders()
  headers["Upgrade"] = "websocket"
  headers["Connection"] = "Upgrade"
  headers["Sec-WebSocket-Key"] = base64.encode("ryton-websocket-key")
  headers["Sec-WebSocket-Version"] = "13"
  
  let response = client.get(url, headers = headers)
  return response.statusCode == 101

# ============================================================================
# УТИЛИТЫ ДЛЯ ТЕСТИРОВАНИЯ API
# ============================================================================

proc testEndpoint*(client: RequestsClient, url: string, expectedStatus: int = 200): bool =
  ## Тестирует доступность эндпоинта
  try:
    let response = client.get(url)
    return response.statusCode == expectedStatus
  except:
    return false

proc benchmarkEndpoint*(client: RequestsClient, url: string, requests: int = 100): tuple[avgTime: float, successRate: float] =
  ## Бенчмарк эндпоинта
  var totalTime = 0.0
  var successCount = 0
  
  for i in 0..<requests:
    let startTime = cpuTime()
    try:
      let response = client.get(url)
      if response.isSuccess():
        inc successCount
    except:
      discard
    totalTime += cpuTime() - startTime
  
  result = (
    avgTime: totalTime / float(requests),
    successRate: float(successCount) / float(requests) * 100.0
  )

proc loadTest*(client: RequestsClient, url: string, duration: int, concurrency: int = 10): tuple[totalRequests: int, successRate: float, avgTime: float] =
  ## Нагрузочное тестирование
  let endTime = cpuTime() + float(duration)
  var totalRequests = 0
  var successCount = 0
  var totalTime = 0.0
  
  # Упрощенная реализация без реального параллелизма
  while cpuTime() < endTime:
    let startTime = cpuTime()
    try:
      let response = client.get(url)
      if response.isSuccess():
        inc successCount
    except:
      discard
    
    inc totalRequests
    totalTime += cpuTime() - startTime
  
  result = (
    totalRequests: totalRequests,
    successRate: float(successCount) / float(totalRequests) * 100.0,
    avgTime: totalTime / float(totalRequests)
  )

# ============================================================================
# ЭКСПОРТ ОСНОВНЫХ ФУНКЦИЙ И ТИПОВ
# ============================================================================

# Экспортируем все основные типы и функции
export RequestsClient, RequestResult, RequestConfig, AuthInfo, AuthType, ProxyInfo
export RequestException, ConnectionError, TimeoutError, HTTPError, TooManyRedirects
export newRequestsClient, get, post, put, delete, patch, head, options
export enableLogging, enableMocking, addMockRule, clearMockRules
export getMetrics, resetMetrics, printMetrics
export newRestApiClient, newGraphQLClient, newWebhookClient
export setGlobalTimeout, setGlobalUserAgent, setGlobalAuth, setGlobalProxy

# ============================================================================
# ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ В КОММЕНТАРИЯХ
# ============================================================================

when isMainModule:
  # Примеры использования:
  
  # Простой GET запрос
  let response = get("https://api.example.com/users")
  echo response.body
  
  # POST с JSON данными
  let data = %*{"name": "John", "email": "john@example.com"}
  let result = post("https://api.example.com/users", json = data)
  
  # Создание клиента с настройками
  let client = newRequestsClient("https://api.example.com")
  client.setAuth(authBearer, token = "your-token")
  client.setTimeout(60)
  
  # Загрузка файла
  discard client.uploadFile("/upload", "document.pdf")
  
  # Скачивание файла
  discard client.downloadFile("/download/file.zip", "local_file.zip")
  
  # Работа с сессиями
  let session = client.createSession()
  let loginResult = session.post("/login", data = "username=user&password=pass")
  let profileResult = session.get("/profile")  # Куки сохранятся
  
  # Мокирование для тестов
  enableMocking()
  addMockRule(HttpGet, "/test", 200, """{"status": "ok"}""")
  let mockResponse = get("/test")  # Вернет мок
  
  # Метрики и логирование
  enableLogging(logRequests = true, logResponses = true)
  printMetrics()
