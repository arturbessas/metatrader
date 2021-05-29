//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

#define MAX_TRIES 5

//--- input parameters

input int nContratos = 1;
input int hora_inicial = 9;
input int minuto_inicial = 0;
input int hora_limite = 16;
input int minuto_limite = 30;
input int lossMonthsAllowed = 0;
input int periodoMedia;
input double numeroDesvios;
input int periodoGrafico;
input int trendwise;
input double stopLoss;
input double takeProfit;

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
MqlDateTime tempo;
int lastMonth;
int attempts;
int i, j, k;
double optResult = 0.0;
int monthsWithLoss = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    ArraySetAsSeries(aux, true);
    bbHandle = iBands(_Symbol, getPeriodoGrafico(), periodoMedia, 0, numeroDesvios, PRICE_CLOSE);
    stock = Symbol();

    TimeToStruct(TimeCurrent(), tempo);
    lastMonth = tempo.mon;

    return (INIT_SUCCEEDED);
}

double OnTester()
{
    if (TesterStatistics(STAT_PROFIT) == 0)
        return -200;
    return optResult + 0.000001 * TesterStatistics(STAT_PROFIT);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    if (!isValidStrategy())
        ExpertRemove();

    if (!validTick())
        return;

    getBB();

    //regra de entrada
    if (!posManager.Select(stock) && getSignal() != "")
    {
        tpSent = false;
        attempts = 0;
        do
        {
            if ((trendwise && getSignal() == "up") || (!trendwise && getSignal() == "down"))
            {
                trade.Buy(nContratos, stock, 0.0, tick.last - stopLoss, 0.0, "Compra por rompimento de banda");
                opType = "buy";
            }
            else
            {
                trade.Sell(nContratos, stock, 0.0, tick.last + stopLoss, 0.0, "Venda por rompimento de banda");
                opType = "sell";
            }
        } while (trade.ResultRetcode() != 10009 && ++attempts < MAX_TRIES);
    }
    //update stops
    if (posManager.Select(stock) && !tpSent)
    {
        double tp = opType == "buy" ? posManager.PriceOpen() + takeProfit : posManager.PriceOpen() - takeProfit;
        double sl = opType == "buy" ? posManager.PriceOpen() - stopLoss : posManager.PriceOpen() + stopLoss;
        //usado para permitir o positionModify
        //double tpFake = opType == "buy" ? posManager.PriceOpen() + 100 : posManager.PriceOpen() - 100;
        trade.PositionModify(stock, sl, tp);

        //if(opType == "buy")
        //	trade.SellLimit(1, tp, stock);
        //else
        //	trade.BuyLimit(1, tp, stock);

        //tpOrder = trade.ResultOrder();
        tpSent = true;
    }
}

string getSignal()
{
    double price = tick.last;
    if (price > bbUp)
        return "up";
    if (price < bbDown)
        return "down";

    return "";
}

void getBB()
{
    CopyBuffer(bbHandle, 1, 0, 1, aux);
    bbUp = aux[0];
    CopyBuffer(bbHandle, 2, 0, 1, aux);
    bbDown = aux[0];
}

bool validTick()
{
    if (!SymbolInfoTick(Symbol(), tick))
        return false;

    bool isPositioned = posManager.Select(stock);

    TimeToStruct(tick.time, tempo);

    if (tempo.mon != lastMonth)
    {
        checkMonthlyProfit();
        lastMonth = tempo.mon;
    }

    if ((tempo.hour < hora_inicial) || (tempo.hour == hora_inicial && tempo.min < minuto_inicial))
    {
        return false;
    }

    //if(!isPositioned && order.Select(tpOrder))
    //{
    //	if(order.State() != ENUM_ORDER_STATE::ORDER_STATE_FILLED)
    //		cancelStopGain();
    //}

    if (!isPositioned && ((tempo.hour == hora_limite && tempo.min >= minuto_limite) || tempo.hour > hora_limite))
        return false;

    if (isPositioned && tempo.hour >= 17 && tempo.min >= 30)
    {
        trade.PositionClose(stock);
        //cancelStopGain();
        return false;
    }

    return true;
}

void cancelStopGain()
{
    trade.OrderDelete(tpOrder);
    tpOrder = 0;
}

void checkMonthlyProfit()
{
    int year = lastMonth == 12 ? tempo.year - 1 : tempo.year;
    datetime ini = StringToTime(StringFormat("%d.%d.01 06:00:00", year, lastMonth));
    datetime fin = StringToTime(StringFormat("%d.%d.01 06:00:00", tempo.year, tempo.mon));

    HistorySelect(ini, fin);
    ulong auxTicket;
    double result = 0;

    for (i = 0; i < HistoryDealsTotal(); i++)
    {
        auxTicket = HistoryDealGetTicket(i);
        result += HistoryDealGetDouble(auxTicket, DEAL_PROFIT);
    }

    if (result < 0)
    {
        monthsWithLoss++;
    }
    if (monthsWithLoss > lossMonthsAllowed)
    {
        optResult -= 200;
        ExpertRemove();
    }
    else
    {
        optResult += 1.0;
    }
}

bool isValidStrategy()
{
    if (hora_inicial > hora_limite)
        return false;

    if (hora_inicial == hora_limite && minuto_inicial >= minuto_limite)
        return false;

    return true;
}

ENUM_TIMEFRAMES getPeriodoGrafico()

{
    switch (periodoGrafico)
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
