//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Enums.mqh>;

#define MAX_TRIES 5

//--- input parameters
input group "#---# Parâmetros do robô #---#"
input periodicity_enum candle_periodicity; //Tempo gráfico
input int number_of_stocks = 1; //Quantidade por ordem
input int magic_number = 0;
input int periodoMedia;
input double numeroDesvios;
input int trendwise;
input double stop_gain_distance; //Valor stop gain
input double stop_loss_distance; //Valor do stop loss
input int start_hour = 9; //Hora inicial para abrir posições
input int start_min = 0; //Minuto inicial para abrir posições
input int last_hour = 16; //Hora final para abrir posições
input int last_min = 30; //Minuto final para abrir posições
input bool_enum using_daily_loss; //Usar stop diário de perda
input double daily_loss; //Stop loss diário
input bool_enum using_daily_gain; //Usar stop diário de ganho
input double daily_gain; //Stop gain diário
input bool_enum using_trades_limit; // Parar após X trades no dia
input int max_trades; //Número de trades

#include <Context.mqh>
#include <StopLoss.mqh>
#include <StopGain.mqh>
#include <DailyStopLoss.mqh>
#include <DailyStopGain.mqh>
#include <TradesLimit.mqh>


int bbHandle;
double media;
double bbUp;
double bbDown;
double aux[];
string opType;

Context *context;
TickInfo tick;
ENUM_TIMEFRAMES periodicity;

// Declare modules
StopLoss *stop_loss;
StopGain *stop_gain;
DailyStopLoss *daily_stop_loss;
DailyStopGain *daily_stop_gain;
TradesLimit *trades_limit;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{	
	context = new Context();
	context.trade.SetTypeFilling(ORDER_FILLING_RETURN);
	if(!context.is_testing())
		ExpertRemove();
	
	periodicity = context.get_periodicity(candle_periodicity);
	
	// Init modules
	stop_loss = new StopLoss(stop_loss_distance);
	stop_gain = new StopGain(stop_gain_distance);
	daily_stop_loss = new DailyStopLoss(using_daily_loss, daily_loss);
	daily_stop_gain = new DailyStopGain(using_daily_gain, daily_gain);
	trades_limit = new TradesLimit(using_trades_limit, max_trades);
	
	ArraySetAsSeries(aux,true);
	bbHandle = iBands(_Symbol, periodicity,periodoMedia,0,numeroDesvios,PRICE_CLOSE);
	
	return(INIT_SUCCEEDED);
}

double OnTester()
{
	if(TesterStatistics(STAT_PROFIT) == 0)
		return -200;
	if(using_min_trades_per_day && TesterStatistics(STAT_DEALS) / context.optimizer.days_with_market < min_trades_per_day)
		return -100;
	if(using_max_weeks && context.optimizer.weeks_with_loss / context.optimizer.number_of_weeks > max_weeks_percentage / 100)
		return -150;
	if(using_max_dd && TesterStatistics(STAT_BALANCE_DDREL_PERCENT) > max_dd)
		return -175;
	
	return context.optimizer.opt_result + 0.000001 * TesterStatistics(STAT_PROFIT);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	stop_gain.on_order((MqlTradeTransaction)trans);
	context.on_order((MqlTradeTransaction)trans);
	trades_limit.on_order();
}

void OnTick()
{
	// Basic validations
	if(!context.valid_strategy)
		ExpertRemove();
		
	//Call modules on_trade function
	daily_stop_loss.on_trade();
	daily_stop_gain.on_trade();
	stop_loss.on_trade();
	
	if(!context.valid_tick(start_hour, start_min, last_hour, last_min))
	{
		return;
	}
		
	tick = context.tick;
		
	getBB();
	
	//regra de entrada
	if(!context.pos_info.Select(Symbol()) && getSignal() != "")
	{
		int attempts = 0;
		do
		{			
			if((trendwise && getSignal() == "up") || (!trendwise && getSignal() == "down"))
			{
				context.trade.BuyLimit((double)number_of_stocks, context.round_price(tick.tick.last),Symbol(), 0, 0, ORDER_TIME_GTC, 0, "Compra por rompimento de banda");
				
			}
			else
			{
				context.trade.SellLimit((double)number_of_stocks, context.round_price(tick.tick.last),Symbol(), 0, 0, ORDER_TIME_GTC, 0, "Venda por rompimento de banda");
				
			}
		}while(context.trade.ResultRetcode() != 10009 && ++attempts < MAX_TRIES);		
	}	
}

string getSignal()
{
	if(!context.is_new_bar)
		return "";
	
	double price = iClose(Symbol(), periodicity, 1);
	
	//PrintFormat("%s up: %f - down: %f - last: %f", last_candle_time, bbUp, bbDown, price);
	if(price > bbUp)
		return "up";
	if(price < bbDown)
		return "down";
		
	return "";
}

void getBB()
{
	CopyBuffer(bbHandle,1,1,1,aux);
	bbUp = aux[0];
	CopyBuffer(bbHandle,2,1,1,aux);
	bbDown = aux[0];
}
