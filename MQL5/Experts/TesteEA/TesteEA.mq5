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
	trade.SetExpertMagicNumber(13);
	trade.Buy(100, Symbol());
	//Sleep(100);
	//trade.Buy(1, Symbol());
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
