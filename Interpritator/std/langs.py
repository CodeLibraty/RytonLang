import sqlite3
import cython

class Run:
	@cython.ccall
	def sql(sql_code):
	    if not sql_code[0]:
	        pass
	    else:
	        try:
	            self.sql_cursor.executescript(sql_code)
	            result = self.sql_cursor.fetchall()
	            return str(result)
	        except Exception as e:
	            return "SQL Error: {e}"
