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
#include <Utils.mqh>

#define MAX_TRIES 5
#define TIMEOUT 30

//--- input parameters
input ulong magic_number = 1;
input datetime final_datetime;
input int nContratos = 1;
input int hora_inicial = 9;
input int minuto_inicial = 0;
input int hora_limite = 16;
input int minuto_limite = 30;
input double max_daily_loss = 500000;
input double max_drawdown = 10000;
input int lossMonthsAllowed = 100;
input int max_stocks = 100;
input int tipoMedia = 2;
input int periodoMedia = 23;
input double dx = 7;
input int periodoGrafico = 1;
input int trendwise = 0;
input double stopLoss;
input double takeProfit;
input int usingSaidaPorDistancia = 0;
input double distanciaParaSaida = 0.5;
input string increasesPtsStr = "";
input string increasesQttStr = "";
input double firstIncreasePts = 0;
input int firstIncreaseStocks = 0;
input double secondIncreasePts = 0;
input int secondIncreaseStocks = 0;
input double thirdIncreasePts = 0;
input int thirdIncreaseStocks = 0;
input double fourthIncreasePts = 0;
input int fourthIncreaseStocks = 0;
input double fifthIncreasePts = 0;
input int fifthIncreaseStocks = 0;



int mediaHandle;
double media;
double aux[];
bool previousSignal;
bool firstTick = true;
string stock;
posManager pos;
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
MqlDateTime last_day;
double total_profit = 0;
double max_profit = 0;
MqlDateTime final_day;
bool final_day_checked = false;



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
	trade.SetTypeFilling(ORDER_FILLING_RETURN);
	Print("Type filling configurado.");
	ArraySetAsSeries(aux,true);
	mediaHandle = iMA(_Symbol,getPeriodoGrafico(periodoGrafico),periodoMedia,0,getTipoMedia(tipoMedia),PRICE_CLOSE);
	stock = Symbol();
	validStrategy = processIncreases();
	if(validStrategy && increasesPtsStr == "")
		validStrategy = reprocessIncreases();
		
	//if(validStrategy)
	//	validStrategy = getMaxLoss();
	
	//if(validStrategy)
	//	validStrategy = cutSomeSheet();
		
	TimeToStruct(TimeCurrent(), last_day);
	lastMonth = last_day.mon;
	TimeToStruct(final_datetime, final_day);
	
	trade.SetExpertMagicNumber(magic_number);
	PrintFormat("Magic number setado: %d", magic_number);	
	
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
		
	getMedia();
	
	if(!validTick() || !validStrategy)
		return;			
	
	//regra de entrada
	if(pos.owned_stocks == 0 && !isEntryLocked())
		getEntry();
		
		
	storeSignals();	
	
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	update_position_info((MqlTradeTransaction)trans, pos);
	PrintFormat("Owned: %d - Preço: %f", pos.owned_stocks, pos.average_price);	
	
	if(pos.owned_stocks != 0)
	{
		if(trans.order == lastIncreaseOrder && trans.order_state == ORDER_STATE_FILLED)
		{		
			if(increaseStep == 0)
			{
				entryPrice = trans.price;
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
				
				logger.info("Aumento de posição enviado.");
				lastIncreaseOrder = trade.ResultOrder();
			}			
			//update stop gain if a increase was executed
			if(order.Select(tpOrder) && increaseStep > 0)
			{				
				trade.OrderDelete(tpOrder);			
				logger.info("Deletando TP para envio de nova ordem de TP.");	
				double tp = opType == "buy" ? pos.average_price + takeProfit : pos.average_price - takeProfit;
				if(opType == "buy")
					trade.SellLimit(MathAbs(pos.owned_stocks), roundPrice(tp), stock);
				else if(opType == "sell")
					trade.BuyLimit(MathAbs(pos.owned_stocks), roundPrice(tp), stock);
				
				logger.info("TP atualizado.");
					
				tpOrder = trade.ResultOrder();
			}					
			
			increaseStep++;
		}			
	}

}

void sendTP()
{
	if(pos.owned_stocks != 0 && !tpSent)
	{
		double tp = opType == "buy" ? pos.average_price + takeProfit : pos.average_price - takeProfit;
		int attempts = 0;		
		if(opType == "buy")
			trade.SellLimit(MathAbs(pos.owned_stocks), roundPrice(tp), stock);
		else
			trade.BuyLimit(MathAbs(pos.owned_stocks), roundPrice(tp), stock);
		
		logger.info("TP Enviado.");
		tpOrder = trade.ResultOrder();
		tpSent = true;
	}
}

void getEntry()
{
	if(getSignal() != "")
	{
		tpSent = false;
		lockEntries = true;
		increaseStep = 0;
		int attempts = 0;
		entryPrice = 0;
		do
		{
			attempts++;
			if((trendwise && getSignal() == "upper") || (!trendwise && getSignal() == "lower"))
			{
				trade.BuyLimit(nContratos, roundPrice(tick.last), stock, 0.0, 0.0, ORDER_TIME_GTC, 0,  "Compra por rompimento de banda");
				opType = "buy";
			}
			else if((trendwise && getSignal() == "lower") || (!trendwise && getSignal() == "upper"))
			{
				trade.SellLimit(nContratos, roundPrice(tick.last), stock, 0.0, 0.0, ORDER_TIME_GTC, 0,  "Venda por rompimento de banda");
				opType = "sell";
			}
		}while(trade.ResultRetcode() != 10009 && attempts <= MAX_TRIES);
		
		if(attempts <= MAX_TRIES)
		{
			entryTime = tick.time;
			lockEntries = true;
			lastIncreaseOrder = trade.ResultOrder();
			entryPrice = tick.last; //provisório
			logger.info("Ordem de entrada enviada.");
		}
		else
		{
			lockEntries = false;
			logger.info("Desbloqueando entradas por entrada mal sucedida");
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
			logger.info("Cancelando ordem por timeout.");
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
	if(price >= media + dx)
		return "upper";
	if(price <= media - dx)
		return "lower";
		
	return "";
}

void getMedia()
{
	CopyBuffer(mediaHandle,0,0,1,aux);
	media = aux[0];
}

bool validTick()
{
	if(!SymbolInfoTick(Symbol(),tick))
		return false;
		
	bool isPositioned = pos.owned_stocks != 0;
	
	if(isPositioned)
		checkStopLoss();
	
	TimeToStruct(tick.time, tempo);
	
	if(tempo.day != last_day.day)
	{
		check_daily_profit();
		TimeToStruct(tick.time, last_day);
	}
	
	if(tempo.mon != lastMonth)
	{
		checkMonthlyProfit();
		lastMonth = tempo.mon;
	}
	
	if(tempo.day == final_day.day && tempo.mon == final_day.mon && tempo.year == final_day.year && tempo.hour >= 17 && tempo.min > 30 && !final_day_checked)
	{
		tempo.mon++;
		checkMonthlyProfit();
		final_day_checked = true;
		tempo.mon--;
	}
	
	if((tempo.hour < hora_inicial) || (tempo.hour == hora_inicial && tempo.min < minuto_inicial))
	{
		increaseStep = 0;
		lastIncreaseOrder = 0;
		tpOrder = 0;
		return false;
	}
	
	if(!isPositioned && order.Select(tpOrder))
	{
		if(order.State() != ORDER_STATE_FILLED && order.State() != ORDER_STATE_CANCELED)
		{
			cancelStopGain();
			logger.info("Cancelando stop gain por não estar posicionado.");
		}
	}
	
	if(!isPositioned && order.Select(lastIncreaseOrder) && increaseStep)
	{
		if(order.State() != ORDER_STATE_FILLED && order.State() != ORDER_STATE_CANCELED)
		{
			cancelIncreaseOrder();
			logger.info("Cancelando increase por não estar posicionado.");
		}
	}
	
	if(!isPositioned && ((tempo.hour == hora_limite && tempo.min >= minuto_limite) || tempo.hour > hora_limite))
		return false;
		
	if(isPositioned && tempo.hour >= 17 && tempo.min >= 45)
	{
		trade.PositionClose(stock);
		cancelStopGain();
		cancelIncreaseOrder();
		logger.info("Zerando posição e cancelando ordens por tempo limite.");
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
		logger.info("Zerando posição e cancelando ordens por stop loss.");
		logger.info(opType + " Last: " + DoubleToString(tick.last) + " entry: " + DoubleToString(entryPrice) + " sl: " + DoubleToString(stopLoss));
	}
	
	//saida por toque
	if(usingSaidaPorDistancia && MathAbs(tick.last - media) <= distanciaParaSaida)
	{
		trade.PositionClose(stock);
		cancelStopGain();
		cancelIncreaseOrder();
		logger.info("Zerando posição e cancelando ordens por toque na media.");
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
		int stocks = increasesQtt[0] + nContratos;
		
		for(int i=1; i<increaseNumber; i++)
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
	for(int i=0; i<ArraySize(auxStr); i++)
	{
		add(increasesPts, StringToInteger(auxStr[i]));
	}
	ArrayFree(auxStr);
	StringSplit(increasesQttStr, separator, auxStr);
	for(int i=0; i<ArraySize(auxStr); i++)
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
	
	for(int i = 0; i < HistoryDealsTotal(); i++)
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
		logger.info("Max loss months exceeded. Allowed: " + IntegerToString(lossMonthsAllowed) + "; Current: " + IntegerToString(monthsWithLoss)); 
		ExpertRemove();
	}
	else
	{
		optResult += 1.0;
	}
}

void check_daily_profit()
{
	datetime ini = StructToTime(last_day);
	datetime fin = TimeCurrent();
	
	HistorySelect(ini,fin);
	ulong auxTicket;
	double result = 0;
	
	for(int i = 0; i < HistoryDealsTotal(); i++)
	{
		auxTicket = HistoryDealGetTicket(i);
		result += HistoryDealGetDouble(auxTicket, DEAL_PROFIT);
	}
	
	if(result < -max_daily_loss)
	{
		optResult -= 180;
		logger.info("Max daily loss exceeded. Stopping backtest. Max: " + DoubleToString(max_daily_loss) + "; Current: " + DoubleToString(result));
		ExpertRemove();
	}
	
	total_profit += result;
	
	if(total_profit > max_profit)
		max_profit = total_profit;
	
	if(max_profit - total_profit > max_drawdown)
	{
		optResult -= 200;
		logger.info("Max drawdown exceeded. Stopping backtest. Max DD: " + DoubleToString(max_drawdown) + "; Current DD: " + DoubleToString(max_profit - total_profit));
		ExpertRemove();
	}
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

double roundPrice(double price)
{
	double min_var = 0.01;
	if(StringFind(stock, "WIN") >= 0 || StringFind(stock,"IND") >= 0)
		min_var = 5.0;
	else if(StringFind(stock, "WDO") >= 0 || StringFind(stock,"DOL") >= 0)
		min_var = 0.5;
	double ticks = price / min_var;
	return round(ticks) * min_var;
}

void recoverSignals()
{
	string name = "tpOrder" + IntegerToString(magic_number);
	tpOrder = (ulong)GlobalVariableGet(name);
	
	name = "lastIncreaseOrder" + IntegerToString(magic_number);
	lastIncreaseOrder = (ulong)GlobalVariableGet(name);
	
	name = "increaseStep" + IntegerToString(magic_number);
	increaseStep = (int)GlobalVariableGet(name);

	name = "entryPrice" + IntegerToString(magic_number);
	entryPrice = GlobalVariableGet(name);
	
	name = "entryOrder" + IntegerToString(magic_number);
	entryOrder = (ulong)GlobalVariableGet(name);
	
	name = "lockEntries" + IntegerToString(magic_number);
	lockEntries = (bool)GlobalVariableGet(name);
	
	name = "above" + IntegerToString(magic_number);
	above = (bool)GlobalVariableGet(name);
	
	name = "lockEntriesByLoss" + IntegerToString(magic_number);
	lockEntriesByLoss = (bool)GlobalVariableGet(name);
}


void storeSignals()
{	
	string name = "tpOrder" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)tpOrder);
	
	name = "lastIncreaseOrder" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)lastIncreaseOrder);
	
	name = "increaseStep" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)increaseStep);

	name = "entryPrice" + IntegerToString(magic_number);
	GlobalVariableSet(name, entryPrice);
	
	name = "entryOrder" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)entryOrder);
	
	name = "lockEntries" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)lockEntries);
	
	name = "above" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)above);
	
	name = "lockEntriesByLoss" + IntegerToString(magic_number);
	GlobalVariableSet(name, (double)lockEntriesByLoss);
}