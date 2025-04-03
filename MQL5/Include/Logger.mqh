//+------------------------------------------------------------------+
//|                                                     Logger.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


class Logger
{	
	public:
	Logger(void);
	~Logger(){};
	
	void info(string message);
	void debug(string message);
	void error(string message);
	
	private:
	void print(string message);

};

Logger::Logger(void){}

void Logger::print(string message)
{
   if (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;
      
	PrintFormat("id: %d - %s", magic_number, message);
}

void Logger::info(string message)
{
   print(message);
}

void Logger::debug(string message)
{
   if(MQLInfoInteger(MQL_DEBUG))
      print(message);
}

void Logger::error(string message)
{
   print("ERROR! " + message);
   if (MQLInfoInteger(MQL_TESTER))
      ExpertRemove();
}