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
string stocksList[3];
MqlTick tick;

int OnInit()
{
	MqlTradeRequest request = {};
	MqlTradeResult result = {};
	
	stocksList[0] = "PETR4";
	stocksList[1] = "MGLU3";
	stocksList[2] = "VALE3";
	
	return INIT_SUCCEEDED;
}

void OnTick()
{
	for(int i=0; i<3; i++)
	{
		string stockCode = stocksList[i];
		
		if(!SymbolInfoTick(stockCode, tick))
			return;
		
		if(!pos.Select(stockCode))
		{
			trade.Buy(100, stockCode, tick.ask, tick.last - 0.2, tick.last + 0.2, stockCode);
		}
	} 
}
