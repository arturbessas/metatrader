//+------------------------------------------------------------------+
//|                                                      TesteEA.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
//#property icon "image.ico"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo pos;
MqlTick tick;

int OnInit()
{
   trade.SetExpertMagicNumber(13);
   
   trade.Buy(0.01);
   Sleep(1000);
   trade.Sell(0.05);
	return INIT_SUCCEEDED;
}

void OnTick()
{
	/*for(int i=0; i<3; i++)
	{
		string stockCode = stocksList[i];
		
		if(!SymbolInfoTick(stockCode, tick))
			return;
		
		if(!pos.Select(stockCode))
		{
			trade.Buy(100, stockCode, tick.ask, tick.last - 0.2, tick.last + 0.2, stockCode);
		}
	} */
	
}
