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
   datetime current_candle_time = TimeCurrent() / PeriodSeconds(PERIOD_M1);
   Print(TimeCurrent());
   Print(current_candle_time);
   
   for(int i=0;i<20;i++)
     {
         Sleep(5000);
   
   current_candle_time = TimeCurrent() / PeriodSeconds(PERIOD_M1);
   Print(TimeCurrent());
   Print(current_candle_time);
     }
   
   
   
   
   
}
//+------------------------------------------------------------------+
