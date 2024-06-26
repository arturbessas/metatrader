//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <StockCodes.mqh>
#include <Generic\HashMap.mqh>
#include <Context.mqh>
#include <StopLoss.mqh>
#include <MarketStopGain.mqh>
#include <PositionIncreaserMarket.mqh>

#define MAX_TRIES 5
#define TIMEOUT 30

//--- input parameters
input double max_loss = 500000;
input int lossMonthsAllowed = 0;
input int max_stocks = 1000;
input int numberOfStocks = 100;
input int tipoMedia;
input int periodoMedia;
input double dx;
input int periodoGrafico;
input int trendwise;
input double stopLoss;
input double takeProfit;
input string increasesQttStr = "";
input string increasesPtsStr = "";
input double firstIncreasePts = 0;
input double firstIncreaseStocks = 0;
input double secondIncreasePts = 0;
input double secondIncreaseStocks = 0;
input double thirdIncreasePts = 0;
input double thirdIncreaseStocks = 0;
input double fourthIncreasePts = 0;
input double fourthIncreaseStocks = 0;
input double fifthIncreasePts = 0;
input double fifthIncreaseStocks = 0;

CHashMap<string, Context*> ContextMap;
CHashMap<string, StopLoss*> StopLossMap;
CHashMap<string, MarketStopGain*> MarketStopGainMap;
CHashMap<string, PositionIncreaserMarket*> PositionIncreaserMarketMap;
CHashMap<string, int> mediaHandle;
double media;
double aux[];
bool previousSignal;
bool firstTick = true;
CPositionInfo posManager;
CTrade trade;
COrderInfo order;
MqlTick tick;
bool tpSent = false;
string opType;
ulong tpOrder = 0;
ulong lastIncreaseOrder = 0;
MqlDateTime tempo;
int increaseStep = 0;
int increaseNumber = 0;
int separator = StringGetCharacter(",", 0);
double increasesPts[];
int increasesQtt[];
//int i, j, k;
bool validStrategy = true;
ulong entryOrder = 0;
bool lockEntries = false;
datetime entryTime;
int lastMonth;
bool above = true;
bool lockEntriesByLoss = false;
double optResult = 0.0;
int monthsWithLoss = 0;
double expiredIncrease = 0.0;
double expiredIncreaseVolume = 0;
double expiredTP = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
	trade.SetTypeFilling(ORDER_FILLING_FOK);
	ArraySetAsSeries(aux,true);
	for(int i = 0; i < ArraySize(stockCodes), i++)
		mediaHandle.add(stockCodes[i], iMA(stockCodes[i],getPeriodoGrafico(),periodoMedia,0,getTipoMedia(),PRICE_CLOSE));
	validStrategy = processIncreases();
	if(validStrategy && increasesPtsStr == "")
		validStrategy = reprocessIncreases();
		
	//init modules
		
	TimeToStruct(TimeCurrent(), tempo);
	lastMonth = tempo.mon;
	
	return(INIT_SUCCEEDED);
}

double OnTester()
{
	if(TesterStatistics(STAT_PROFIT) == 0)
		return -200;
	return optResult + 0.000001 * TesterStatistics(STAT_PROFIT);
}

void OnDeinit(const int reason)
{
	
}

void OnTick()
{
	if(!validStrategy)
		ExpertRemove();
		
	for(int i=0; i<ArraySize(stockCodes); i++)
	{
		stockCode = stockCodes[i];
		
		getMedia(stockCode);	
		
		if(!validTick(stockCode))
			return;			
			
		if(expiredIncreaseVolume != 0)
			handleExpiredIncrease();
		if(expiredTP != 0)
			handleExpiredTP();
		
		//regra de entrada
		if(!posManager.Select(stock) && !isEntryLocked())
			getEntry();		
	}
	
	
	
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	string stockCode = trans.symbol;
	
	if(posManager.Select(stockCode))
	{
		if(trans.order == lastIncreaseOrder && trans.order_state == ORDER_STATE_FILLED)
		{		
			if(increaseStep == 0)
			{
				entryPrices.TrySetValue(stockCode, posManager.PriceOpen());				
				lockEntries = false;
			}
			
			sendIncreaseAndUpdateTp(stockCode);
		}
		
		else if(trans.order == lastIncreaseOrder && trans.order_state == ORDER_STATE_EXPIRED)
		{
			expiredIncrease = trans.price;
			if(trans.volume)
				expiredIncreaseVolume = trans.volume;				
		}
		//caso abra acima do tp
		if(trans.order == tpOrder && trans.order_state == ORDER_STATE_EXPIRED)
		{
			expiredTP = trans.price;				
		}
	}

}

void sendIncreaseAndUpdateTp(string stockCode)
{
	//update stop gain
	sendTP(stockCode);
	
	double entryPrice;
	entryPrices.TryGetValue(stockCode, entryPrice);
	
	//send new increase
	if(increaseStep < increaseNumber)
	{
		if(opType == "buy")
			trade.BuyLimit(increasesQtt[increaseStep], roundPrice(entryPrice * (1 - (increasesPts[increaseStep]/100))), stock, 0, 0, ORDER_TIME_GTC, 0, "Aumento de posicao " + string(increaseStep));
					
		lastIncreaseOrder = trade.ResultOrder();
	}
	
	increaseStep++;
}

void sendTP(string stockCode)
{
	if(order.Select(tpOrder))
	{
		trade.OrderDelete(tpOrder);		
	}
	
	double tp = posManager.PriceOpen() * (1 + (takeProfit/100));
	
	if(opType == "buy")
		trade.SellLimit(posManager.Volume(), roundPrice(tp), stock, 0, 0, ORDER_TIME_GTC, 0, "Take Profit");
	
	tpOrder = trade.ResultOrder();	
}

void handleExpiredTP()
{
	if(opType == "buy" && tick.last >= expiredTP)
	{
		trade.PositionClose(stock);
		expiredTP = 0.0;
	}
	else if(opType == "sell" && tick.last <= expiredTP)
	{
		trade.PositionClose(stock);			
		expiredTP = 0.0;
	}
	else if(!order.Select(tpOrder))
		sendTP();
	if(tpOrder)
		expiredTP = 0.0;
}

void handleExpiredIncrease()
{
	if(opType == "buy" && tick.last < expiredIncrease)
	{
		trade.Buy(expiredIncreaseVolume, stock, 0,0,0,"Aumento de posicao a mercado");
		lastIncreaseOrder = trade.ResultOrder();
	}
	else if(opType == "sell" && tick.last > expiredIncrease)
	{
		trade.Sell(expiredIncreaseVolume, stock, 0,0,0,"Aumento de posicao a mercado");
		lastIncreaseOrder = trade.ResultOrder();
	}
	else
	{
		increaseStep--;
		sendIncreaseAndUpdateTp();
	}
	
	expiredIncrease = 0;
	expiredIncreaseVolume = 0;
}

void getEntry()
{
	if(getSignal() != "")
	{
		tpSent = false;
		increaseStep = 0;
		int attempts = 0;
		entryPrice = 0;
		do
		{
			attempts++;
			if((!trendwise && getSignal() == "lower"))
			{
				trade.BuyLimit(numberOfStocks, tick.last, stock, 0.0, 0.0, ORDER_TIME_GTC, 0,  "Compra por rompimento de banda");
				opType = "buy";
			}
			
			if(trade.ResultRetcode() != 10009)
				Sleep(100);
				
		}while(trade.ResultRetcode() != 10009 && attempts <= MAX_TRIES);
		
		if(attempts <= MAX_TRIES)
		{
			entryTime = tick.time;
			lockEntries = true;
			lastIncreaseOrder = trade.ResultOrder();
		}		
	}
}

bool isEntryLocked()
{
	if(lockEntries)
	{
		if(tick.time - entryTime > TIMEOUT)
		{
			lockEntries = false;
			trade.OrderDelete(lastIncreaseOrder);
			lastIncreaseOrder = 0;			
		}
	}
	
	bool currentlyAbove;
	if(lockEntriesByLoss)
	{
		currentlyAbove = iClose(stock,PERIOD_CURRENT,0) > media;
		lockEntriesByLoss = currentlyAbove == above;
	}
	
	return lockEntries || lockEntriesByLoss;
}

string getSignal()
{
	double price = tick.last;
	//if(price >= media + dx)
	//	return "upper";
	if(price <= media * (1 - (dx/100)))
		return "lower";
		
	return "";
}

void getMedia(string stockCode)
{	
	int handle;
	mediaHandle.TryGetValue(stockCode, handle);
	CopyBuffer(handle,0,0,1,aux);
	media = aux[0];
}

bool validTick(string stockCode)
{
	if(!SymbolInfoTick(stockCode, tick))
		return false;
		
	bool isPositioned = posManager.Select(stockCode);
	
	if(isPositioned)
		checkStopLoss();
	
	TimeToStruct(tick.time, tempo);
	
	if(tempo.mon != lastMonth)
	{
		checkMonthlyProfit();
		lastMonth = tempo.mon;
	}		
	
	if(!isPositioned && order.Select(tpOrder))
	{
		if(order.State() != ORDER_STATE_FILLED && order.State() != ORDER_STATE_CANCELED)
			cancelStopGain();
	}
	
	if(!isPositioned && order.Select(lastIncreaseOrder) && increaseStep)
	{
		if(order.State() != ORDER_STATE_FILLED && order.State() != ORDER_STATE_CANCELED)
			cancelIncreaseOrder();
	}			
	
	if(!isPositioned && tempo.hour >= 17)
		return false;

/*		
	if(isPositioned && tempo.hour >= 17 )
	{
		int year = tempo.year - 2020;
		int month = tempo.mon;
		if(tempo.day == lastDays[year][month])
		{
			trade.PositionClose(stock);
			cancelStopGain();
			cancelIncreaseOrder();
		return false;
		}
	}	
*/
	
	return true;
}

void checkStopLoss(string stockCode)
{	
	if((tick.last <= entryPrice * (1 - (stopLoss/100))))
	{
		trade.PositionClose(stockCode);
		cancelStopGain();
		cancelIncreaseOrder();
		lockEntriesByLoss = true;
		above = tick.last > media;
	}
}

void cancelStopGain()
{
	trade.OrderDelete(tpOrder);
	tpOrder = 0;
}

void cancelIncreaseOrder()
{
	trade.OrderDelete(lastIncreaseOrder);
	lastIncreaseOrder = 0;
}

bool reprocessIncreases()
{
	if(firstIncreasePts && firstIncreaseStocks)
	{
		add(increasesPts, firstIncreasePts);
		add(increasesQtt, firstIncreaseStocks);
		if(secondIncreasePts && secondIncreaseStocks)
		{
			add(increasesPts, secondIncreasePts);
			add(increasesQtt, secondIncreaseStocks);
			if(thirdIncreasePts && thirdIncreaseStocks)
			{
				add(increasesPts, thirdIncreasePts);
				add(increasesQtt, thirdIncreaseStocks);
				if(fourthIncreasePts && fourthIncreaseStocks)
				{
					add(increasesPts, fourthIncreasePts);
					add(increasesQtt, fourthIncreaseStocks);
					if(fifthIncreasePts && fifthIncreaseStocks)
					{
						add(increasesPts, fifthIncreasePts);
						add(increasesQtt, fifthIncreaseStocks);
					}
				}
			}
		}			
	}
	
	increaseNumber = ArraySize(increasesPts);
	
	if(increaseNumber)
	{
		int stocks = increasesQtt[0] + 1;
		
		for(i=1; i<increaseNumber; i++)
		{
			if(increasesPts[i] <= increasesPts[i-1])
				return false;
			stocks += increasesQtt[i];
		}		

		if(increasesPts[increaseNumber-1] >= stopLoss || stocks > max_stocks)
			return false;
	}
	
	return true;
	
}

bool processIncreases()
{
	if(increasesPtsStr == "" && increasesQttStr == "")
		return true;
		
	string auxStr[];
	
	StringSplit(increasesPtsStr, separator, auxStr);
	for(i=0; i<ArraySize(auxStr); i++)
	{
		add(increasesPts, StringToInteger(auxStr[i]));
	}
	ArrayFree(auxStr);
	StringSplit(increasesQttStr, separator, auxStr);
	for(i=0; i<ArraySize(auxStr); i++)
	{
		add(increasesQtt, StringToInteger(auxStr[i]));
	}
	
	if(ArraySize(increasesPts) != ArraySize(increasesQtt))
		return false;
		
	increaseNumber = ArraySize(increasesPts);
	
	if(increasesPts[increaseNumber-1] >= stopLoss)
		return false;
	
	return true;
}

void checkMonthlyProfit()
{
	int year = lastMonth == 12 ? tempo.year - 1 : tempo.year;
	datetime ini = StringToTime(StringFormat("%d.%d.01 06:00:00", year, lastMonth));
	datetime fin = StringToTime(StringFormat("%d.%d.01 06:00:00", tempo.year, tempo.mon));
	
	HistorySelect(ini,fin);
	ulong auxTicket;
	double result = 0;
	
	for(i = 0; i < HistoryDealsTotal(); i++)
	{
		auxTicket = HistoryDealGetTicket(i);
		result += HistoryDealGetDouble(auxTicket, DEAL_PROFIT);
	}
	
	if(result < 0)
	{
		monthsWithLoss++;	
	}
	if(monthsWithLoss > lossMonthsAllowed)
	{
		optResult -= 200;
		ExpertRemove();
	}
	else
	{
		optResult += 1.0;
	}
}

bool getMaxLoss()
{
	int stocks = 1;
	int volume = 0;
	for(i=0; i<increaseNumber; i++)
	{
		volume += increasesPts[i] * increasesQtt[i];
		stocks += increasesQtt[i];
	}
	double average = volume / stocks;
	double loss = (stopLoss - average) * 10 * stocks;
	if(loss > max_loss)
		return false;
	return true;
}

bool cutSomeSheet()
{
	if(increaseNumber < 1 && (firstIncreaseStocks > 13 || firstIncreasePts > 50))
		return false;
	if(increaseNumber < 2 && (secondIncreaseStocks > 13 || secondIncreasePts > 50))
		return false;
	if(increaseNumber < 3 && (thirdIncreaseStocks > 13 || thirdIncreasePts > 50))
		return false;
	if(increaseNumber < 4 && (fourthIncreaseStocks > 13 || fourthIncreasePts > 50))
		return false;
	if(increaseNumber < 5 && (fifthIncreaseStocks > 13 || fifthIncreasePts > 50))
		return false;
		
	return true;
}

void add(int &v[], int x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}

void add(double &v[], double x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}

double roundPrice(double price)
{
	double ticks = price / 0.01;
	return round(ticks) * 0.01;
}


ENUM_TIMEFRAMES getPeriodoGrafico()
{
	switch(periodoGrafico)
	{
	   case 1:
	      return PERIOD_M1;
	      break;
	   case 2:
	      return PERIOD_M2;
	      break;
	   case 3:
	      return PERIOD_M3;
	      break;
	   case 4:
	      return PERIOD_M4;
	      break;
	   case 5:
	      return PERIOD_M5;
	      break;
	   case 6:
	      return PERIOD_M6;
	      break;
	   case 7:
	      return PERIOD_M10;
	      break;
	   case 8:
	      return PERIOD_M12;
	      break;
	   case 9:
	      return PERIOD_M15;
	      break;
	   case 10:
	      return PERIOD_M20;
	      break;
	   case 11:
	      return PERIOD_M30;
	      break;
	   case 12:
	      return PERIOD_H1;
	      break;      
	   default:
	      return _Period;
	}
}
  
ENUM_MA_METHOD getTipoMedia()
{
	switch(tipoMedia)
	  {
	   case 1:
	      return MODE_SMA;
	      break;
	   case 2:
	      return MODE_EMA;
	      break;
	   default:
	      return MODE_SMA;
	  }
}