//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//#include <Enums.mqh>;

#define MAX_TRIES 5

//--- input parameters
input group "#---# Parâmetros do robô #---#"
input periodicity_enum candle_periodicity; //Tempo gráfico
input int number_of_stocks = 1; //Quantidade por ordem
input group "* Bandas de Bollinger *"
input bool_enum using_bb_rule; //Usar Bandas de Bollinger
input bool_enum bb_rule_invert; //Habilita inversão
input bool_enum bb_rule_mode; //Modo de Operação
input bool_enum 
input group "* Stop Gain *"
input bool_enum using_stop_gain; //Usar stop gain
input double stop_gain_distance; //Valor stop gain
input group "* Stop Loss *"
input bool_enum using_stop_loss; //Usar stop loss
input double stop_loss_distance; //Valor do stop loss
input group "* Stop Movel *"
input bool_enum using_stop_movel; //Usar stop móvel de ganho
input double stop_movel_begin; //Valor de ativação
input double stop_movel_distance; //Distância
input group "* Restrições de Horário *"
input int start_hour = 9; //Hora inicial para abrir posições
input int start_min = 0; //Minuto inicial para abrir posições
input int last_hour = 16; //Hora final para abrir posições
input int last_min = 30; //Minuto final para abrir posições
input int elim_hour = 17; //Hora final de eliminação
input int elim_min = 30; //Minuto final de eliminação
input group "* Critérios de Saída Diários *" //Teste
input bool_enum using_daily_loss; //Usar stop diário de perda
input double daily_loss; //Stop loss diário
input bool_enum using_daily_gain; //Usar stop diário de ganho
input double daily_gain; //Stop gain diário
input bool_enum using_trades_limit; // Parar após X trades no dia
input int max_trades; //Número de trades
input bool_enum using_daily_break_even; //Usar break even financeiro diário
input double break_even_begin; //Valor mínimo para ativar o break even
input double break_even_distance; //Declínio do ganho máximo

#include <Context.mqh>
#include <StopLoss.mqh>
#include <StopGain.mqh>
#include <DailyStopLoss.mqh>
#include <DailyStopGain.mqh>
#include <TradesLimit.mqh>
#include <StopMovel.mqh>
#include <DailyBreakEven.mqh>


Context *context;

// Declare modules
StopLoss *stop_loss;
StopGain *stop_gain;
DailyStopLoss *daily_stop_loss;
DailyStopGain *daily_stop_gain;
TradesLimit *trades_limit;
StopMovel *stop_movel;
DailyBreakEven *daily_break_even;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{	
	context = new Context();
	context.trade.SetTypeFilling(ORDER_FILLING_RETURN);
	if(!context.is_testing())
		ExpertRemove();
	
	context.set_periodicity(candle_periodicity);
	
	// Init modules
	// Init modules
	if(using_daily_loss)
	{
		daily_stop_loss = new DailyStopLoss(daily_loss);
		context.on_trade_nodes.Add(daily_stop_loss);
	}
	if(using_stop_loss)
	{
		stop_loss = new StopLoss(stop_loss_distance);
		context.on_trade_nodes.Add(stop_loss);
	}
	if(using_stop_gain)
	{
		stop_gain = new StopGain(stop_gain_distance);
		context.on_order_nodes.Add(stop_gain);
	}	
	if(using_daily_gain)
	{
		daily_stop_gain = new DailyStopGain(daily_gain);
		context.on_trade_nodes.Add(daily_stop_gain);
	}
	if(using_trades_limit)
	{
		trades_limit = new TradesLimit(max_trades);
		context.on_order_nodes.Add(trades_limit);
	}
	if(using_stop_movel)
	{
		stop_movel = new StopMovel(stop_movel_begin, stop_movel_distance);
		context.on_trade_nodes.Add(stop_movel);
	}
	if(using_daily_break_even)
	{
		daily_break_even = new DailyBreakEven(break_even_begin, break_even_distance);
		context.on_trade_nodes.Add(daily_break_even);
	}
	
	
	
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
