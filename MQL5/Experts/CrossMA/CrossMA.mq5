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

//--- input parameters
input int periodoCurta;
input int periodoLonga;
input int periodoGrafico;
input int tipoMedia;
input int trendwise;
input double stopLoss;
input double takeProfit;

int curtaHandle;
int longaHandle;
double mediaCurta;
double mediaLonga;
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
MqlDateTime tempo;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
	ArraySetAsSeries(aux,true);
	curtaHandle = iMA(_Symbol,getPeriodoGrafico(),periodoCurta,0,getTipoMedia(),PRICE_CLOSE);
	longaHandle = iMA(_Symbol,getPeriodoGrafico(),periodoLonga,0,getTipoMedia(),PRICE_CLOSE);
	stock = Symbol();
	
	return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
	
}

void OnTick()
{
	if(!validTick())
		return;
		
	getMedias();	
	
	//regra de entrada
	if(!posManager.Select(stock) && getSignal() != previousSignal)
	{
		previousSignal = getSignal();
		tpSent = false;
		do
		{
			if((trendwise && getSignal()) || (!trendwise && !getSignal()))
			{
				trade.Buy(1.0, stock, 0.0, tick.last - stopLoss, 0.0, "Compra por cruzamento de medias");
				opType = "buy";
			}
			else
			{
				trade.Sell(1.0, stock, 0.0, tick.last + stopLoss, 0.0, "Venda por cruzamento de medias");
				opType = "sell";
			}
		}while(trade.ResultRetcode() != 10009);		
	}
	//update stops
	if(posManager.Select(stock) && !tpSent)
	{
		double tp = opType == "buy" ? posManager.PriceOpen() + takeProfit : posManager.PriceOpen() - takeProfit;
		double sl = opType == "buy" ? posManager.PriceOpen() - stopLoss : posManager.PriceOpen() + stopLoss;
		//usado para permitir o positionModify
		double tpFake = opType == "buy" ? posManager.PriceOpen() + 100 : posManager.PriceOpen() - 100;
		trade.PositionModify(stock, sl, tpFake);	
		
		if(opType == "buy")
			trade.SellLimit(1, tp, stock);
		else
			trade.BuyLimit(1, tp, stock);
		
		tpOrder = trade.ResultOrder();
		tpSent = true;
	}
	
}

void OnTrade()
  {

  }

bool getSignal()
{
	return mediaCurta > mediaLonga;
}

void getMedias()
{
	CopyBuffer(curtaHandle,0,0,1,aux);
	mediaCurta = aux[0];
	CopyBuffer(longaHandle,0,0,1,aux);
	mediaLonga = aux[0];
}

bool validTick()
{
	if(!SymbolInfoTick(Symbol(),tick))
		return false;
		
	bool isPositioned = posManager.Select(stock);
		
	if(firstTick)
	{
		firstTick = false;
		previousSignal = getSignal();
	}
	
	TimeToStruct(tick.time, tempo);
	
	if(!isPositioned && order.Select(tpOrder))
	{
		if(order.State() != ENUM_ORDER_STATE::ORDER_STATE_FILLED)
			cancelStopGain();
	}
	
	if(!isPositioned && ((tempo.hour == 16 && tempo.min >= 30) || tempo.hour > 16))
		return false;
		
	if(isPositioned && tempo.hour >= 17 && tempo.min >= 30)
	{
		trade.PositionClose(stock);
		cancelStopGain();
		return false;
	}	
	
	return true;
}

void cancelStopGain()
{
	trade.OrderDelete(tpOrder);
	tpOrder = 0;
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
//+------------------------------------------------------------------+
