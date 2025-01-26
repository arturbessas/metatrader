//+------------------------------------------------------------------+
//|                                                         test.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

struct position
{
	double volume;
	double entry_price;
	double average_price;
};

void OnStart()
  {
      position s;
      s.volume = 2;
      Print(s.average_price, s.entry_price, s.volume);
      
      
   
  }
//+------------------------------------------------------------------+
