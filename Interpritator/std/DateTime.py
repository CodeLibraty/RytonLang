import time as timex
import datetime

def time(type='std'):
    if type == 'std':
        return str(timex.localtime())
    elif type == 'asc':
        return timex.asctime()
    elif type == 'unix':
        return timex.time()
    elif type == 'utc':
        return str(timex.gmtime())
    else:
        return f'type time {type} not found'

def hours():
    return timex.localtime().tm_hour

def minutes():
    return timex.localtime().tm_min
    
def seconds():
    return timex.localtime().tm_sec

def time_short():
    t = timex.localtime()
    return f"{t.tm_hour}:{t.tm_min}:{t.tm_sec}"

def cal():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def sleep(time=0):
    timex.sleep(time)

def today():
    return datetime.date.today()

def time_stamp(timestamp):
    return datetime.date.fromtimestamp(timestamp)

def iso_cal():
    today = datetime.date.today()
    return today.isocalendar()

def iso_format():
    today = datetime.date.today()
    return today.isoformat()

def glob_time(hour=0, minute=0, second=0, microsecond=0, tzinfo=None):
    return datetime.time(hour, minute, second, microsecond, tzinfo)

def now(tz=None, type='std'):
    if type == 'std':
        return datetime.datetime.now(tz)
    elif type == 'utc':
        return datetime.datetime.utcnow()
    else:
        return f'type time {type} not found'
