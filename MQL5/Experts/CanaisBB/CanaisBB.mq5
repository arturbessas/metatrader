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

#define MAX_TRIES 5
#define TIMEOUT 30

//--- input parameters
input double max_loss = 500000;
input int lossMonthsAllowed = 0;
input int max_stocks = 100;
input int tipoMedia;
input int periodoMedia;
input double numeroDesvios;
input int periodoGrafico;
input int trendwise;
input double stopLoss;
input double takeProfit;
input string increasesQttStr = "";
input string increasesPtsStr = "";
input int firstIncreasePts = 0;
input int firstIncreaseStocks = 0;
input int secondIncreasePts = 0;
input int secondIncreaseStocks = 0;
input int thirdIncreasePts = 0;
input int thirdIncreaseStocks = 0;
input int fourthIncreasePts = 0;
input int fourthIncreaseStocks = 0;
input int fifthIncreasePts = 0;
input int fifthIncreaseStocks = 0;

int bbHandle;
double media;
double bbUp;
double bbDown;
double aux[];
bool previousSignal;
bool firstTick = true;
string stock;
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
int increasesPts[];
int increasesQtt[];
int i, j, k;
double entryPrice = 0.0;
bool validStrategy = true;
ulong entryOrder = 0;
bool lockEntries = false;
datetime entryTime;
int lastMonth;
bool above = true;
bool lockEntriesByLoss = false;
double optResult = 0.0;
int monthsWithLoss = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
	trade.SetTypeFilling(ORDER_FILLING_FOK);
	ArraySetAsSeries(aux,true);
	bbHandle = iBands(_Symbol,getPeriodoGrafico(),periodoMedia,0,numeroDesvios,PRICE_CLOSE);
	stock = Symbol();
	validStrategy = processIncreases();
	if(validStrategy && increasesPtsStr == "")
		validStrategy = reprocessIncreases();
		
	if(validStrategy)
		validStrategy = getMaxLoss();
	
	//if(validStrategy)
	//	validStrategy = cutSomeSheet();
		
	TimeToStruct(TimeCurrent(), tempo);
	lastMonth = tempo.mon;
	
	return(INIT_SUCCEEDED);
}

double OnTester()
{
	if(TesterStatistics(STAT_PROFIT) == 0)
		return -100;
	return optResult + 0.000001 * TesterStatistics(STAT_PROFIT);
}

void OnDeinit(const int reason)
{
	
}

void OnTick()
{
	if(!validStrategy)
		ExpertRemove();
		
	getBB();
	
	if(!validTick() || !validStrategy)
		return;			
	
	//regra de entrada
	if(!posManager.Select(stock) && !isEntryLocked())
		getEntry();
	
	
	
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	if(posManager.Select(stock))
	{
		if(trans.order == lastIncreaseOrder && trans.order_state == ORDER_STATE_FILLED)
		{		
			if(increaseStep == 0)
			{
				entryPrice = posManager.PriceOpen();
				//send stop gain
				sendTP();
				lockEntries = false;
			}
			//send new increase
			if(increaseStep < increaseNumber)
			{
				if(opType == "buy")
					trade.BuyLimit(increasesQtt[increaseStep], roundPrice(entryPrice - increasesPts[increaseStep]), stock);
				else if(opType == "sell")
					trade.SellLimit(increasesQtt[increaseStep], roundPrice(entryPrice + increasesPts[increaseStep]), stock);
					
				lastIncreaseOrder = trade.ResultOrder();
			}			
			//update stop gain if a increase was executed
			if(order.Select(tpOrder) && increaseStep > 0)
			{				
				trade.OrderDelete(tpOrder);				
				double tp = opType == "buy" ? posManager.PriceOpen() + takeProfit : posManager.PriceOpen() - takeProfit;
				if(opType == "buy")
					trade.SellLimit(posManager.Volume(), roundPrice(tp), stock);
				else if(opType == "sell")
					trade.BuyLimit(posManager.Volume(), roundPrice(tp), stock);
					
				tpOrder = trade.ResultOrder();
			}					
			
			increaseStep++;
		}			
	}

}

void sendTP()
{
	if(posManager.Select(stock) && !tpSent)
	{
		double tp = opType == "buy" ? posManager.PriceOpen() + takeProfit : posManager.PriceOpen() - takeProfit;
		int attempts = 0;		
		if(opType == "buy")
			trade.SellLimit(1, tp, stock);
		else
			trade.BuyLimit(1, tp, stock);
		
		tpOrder = trade.ResultOrder();
		tpSent = true;
	}
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
			if((trendwise && getSignal() == "upper") || (!trendwise && getSignal() == "lower"))
			{
				trade.BuyLimit(1.0, tick.last, stock, 0.0, 0.0, ORDER_TIME_GTC, 0,  "Compra por rompimento de banda");
				opType = "buy";
			}
			else if((trendwise && getSignal() == "lower") || (!trendwise && getSignal() == "upper"))
			{
				trade.SellLimit(1.0, tick.last, stock, 0.0, 0.0, ORDER_TIME_GTC, 0,  "Venda por rompimento de banda");
				opType = "sell";
			}
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
	if(price >= bbUp)
		return "upper";
	if(price <= bbDown)
		return "lower";
		
	return "";
}


void getBB()
{
	CopyBuffer(bbHandle,1,0,1,aux);
	bbUp = aux[0];
	CopyBuffer(bbHandle,2,0,1,aux);
	bbDown = aux[0];
	CopyBuffer(bbHandle,0,0,1,aux);
	media = aux[0];
}


bool validTick()
{
	if(!SymbolInfoTick(Symbol(),tick))
		return false;
		
	bool isPositioned = posManager.Select(stock);
	
	if(isPositioned)
		checkStopLoss();
	
	TimeToStruct(tick.time, tempo);
	
	if(tempo.mon != lastMonth)
	{
		checkMonthlyProfit();
		lastMonth = tempo.mon;
	}
	
	if(tempo.hour < 9)
	{
		increaseStep = 0;
		lastIncreaseOrder = 0;
		tpOrder = 0;
		return false;
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
	
	if(!isPositioned && ((tempo.hour == 16 && tempo.min >= 30) || tempo.hour > 16))
		return false;
		
	if(isPositioned && tempo.hour >= 17 && tempo.min >= 30)
	{
		trade.PositionClose(stock);
		cancelStopGain();
		cancelIncreaseOrder();
		return false;
	}	
	
	return true;
}

void checkStopLoss()
{	
	if((opType == "buy" && tick.last <= entryPrice - stopLoss)
	|| (opType == "sell" && tick.last >= entryPrice + stopLoss))
	{
		trade.PositionClose(stock);
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

double roundPrice(double price)
{
	double ticks = price / 0.5;
	return round(ticks) * 0.5;
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
