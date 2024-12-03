import time as timex
import datetime

def time(type='std'):
    if type == 'std':
        return timex.localtime()
    elif type == 'asc':
        return timex.asctime()
    elif type == 'unix':
        return timex.time()
    elif type == 'utc':
        return timex.gmtime()
    else:
        print(f'type time {type} not found')

def cal():
    pass

def sleep(time=0):
    timex.sleep(time)

def today():
    return datetime.date.today()

def time_stump(time_stump):
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
        return datetime.datetime.now(tz=None)
    elif type == 'utc':
        return datetime.datetime.utcnow()
    else:
        print(f'type time {type} not found')
