//+------------------------------------------------------------------+
//|                                                    invistaia.mq5 |
//|                                                     Artur Bessas |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Enums.mqh>
#include <Generic\HashMap.mqh>
#include <Csv.mqh>
/*
enum metrics_enum
{
	p50_pred_amplitude,
	p90_pred_amplitude
};*/

enum metrics_enum
{
	robosb,
	p90_pred_amplitude
};

#define DATETIME_COLUMN "Data_Operacao_D+1"
#define LARGURA_COLUMN  "Largura_Intervalo_p10_p90"

// inputs
input group "#---# Magic Number #---#"
input ulong magic_number = 123;
input group "#---# Parâmetros básicos #---#"
input ENUM_TIMEFRAMES candle_periodicity; //Tempo gráfico
input double number_of_stocks = 1; //Quantidade por ordem

input group "#---# Output do modelo #---#"
input string csv_filename = "input.csv"; //Arquivo com dados do modelo

input group "#---# Critérios de entrada #---#"
input metrics_enum rule_used_metric; //Métrica utilizada
input int period_ma; //Período da média
input double ma_distance; //Distância da média
input bool_enum ma_trendwise = 0; //A favor da tendência
//input double rule_entry_percentage; //(%) mínima para a entrada
//input double rule_max_largura; //Largura_Intervalo_p10_p90 máxima

input group "#---# Stop Gain #---#"
input bool_enum using_stop_gain; //Usar stop gain
input double stop_gain_distance; //Valor stop gain (pts)

input group "#---# Stop Loss #---#"
input bool_enum using_stop_loss; //Usar stop loss
input double stop_loss_distance; //Valor stop loss (pts)

input group "#---# Stop Móvel #---#"
input bool_enum using_stop_movel; //Usar stop móvel
input double stop_movel_begin; //Valor de ativação (pts)
input double stop_movel_distance; //Recuo para stop (pts)

input group "#---# Limites diários #---#"
input bool_enum using_trades_limit; //Usar limite diário de trades
input int trades_limit_value = 3; //Limite diário de trades
input bool_enum using_day_trade; //Apenas day trade
input datetime day_trade_time = datetime("2000-01-01 17:30:00"); //Horário de eliminação (ignorar data)

input group "#---# Aumentos de posição #---#"
input bool_enum using_position_increaser = false; //Usar aumentos de posição
input bool_enum position_increaser_trendwise = false; //A favor da posição
input double increase1_distance=0; //Aumento 1 - Distância
input double increase1_quantity=0; //Aumento 1 - Quantidade
input double increase2_distance=0; //Aumento 2 - Distância
input double increase2_quantity=0; //Aumento 2 - Quantidade
input double increase3_distance=0; //Aumento 3 - Distância
input double increase3_quantity=0; //Aumento 3 - Quantidade
input double increase4_distance=0; //Aumento 4 - Distância
input double increase4_quantity=0; //Aumento 4 - Quantidade
input double increase5_distance=0; //Aumento 5 - Distância
input double increase5_quantity=0; //Aumento 5 - Quantidade


// includes
#include <Logger.mqh>;
#include <Context.mqh>
#include <StopLoss.mqh>
#include <MarketStopGain.mqh>
#include <PositionIncreaserMarket.mqh>
#include <TradesLimit.mqh>
#include <DayTrade.mqh>
#include <StopMovel.mqh>
#include "EntryRule.mqh"
#include "IADistRule.mqh"

// Declare modules
Logger 							logger;
Context 							*context;
StopLoss                   *stop_loss;
MarketStopGain             *stop_gain;
PositionIncreaserMarket    *increaser;
TradesLimit						*trades_limit;
DayTrade							*day_trade;
StopMovel                  *stop_movel;
//InvistaIARule					*entry_rule;
IADistRule						*entry_rule;


int OnInit()
{	
	context = new Context(Symbol(), magic_number, candle_periodicity);
	
	if(using_day_trade)
	{
		day_trade = new DayTrade(day_trade_time);
		context.add_node(day_trade, true, false);
	}
	if(using_stop_gain)
	{
		stop_gain = new MarketStopGain(stop_gain_distance, stop_type_absolute, stop_reference_average);
		context.on_trade_nodes.Add(stop_gain);
	}
	if(using_stop_loss)
	{
		stop_loss = new StopLoss(stop_loss_distance, stop_type_absolute);
		context.on_trade_nodes.Add(stop_loss);
	}
	if(using_position_increaser)
	{
		increaser = new PositionIncreaserMarket(stop_type_absolute,position_increaser_trendwise,increase1_distance,increase1_quantity,increase2_distance,increase2_quantity, increase3_distance, increase3_quantity,increase4_distance, increase4_quantity,increase5_distance, increase5_quantity);
		context.on_trade_nodes.Add(increaser);
	}
	if(using_trades_limit)
	{
		trades_limit = new TradesLimit(trades_limit_value);
		context.add_node(trades_limit, false, true);
	}
	if(using_stop_movel)
	{
	   stop_movel = new StopMovel(stop_type_absolute, stop_movel_begin, stop_movel_distance);
	   context.add_node(stop_movel, true, false);
	}
	
	//entry_rule = new InvistaIARule(EnumToString(rule_used_metric), rule_entry_percentage, rule_max_largura);
	entry_rule = new IADistRule(EnumToString(rule_used_metric), period_ma, ma_distance, ma_trendwise);
	context.add_node(entry_rule, true, false);
	
	return INIT_SUCCEEDED;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	// Call modules on_trade function
	context.on_deal((MqlTradeTransaction)trans);
	
	return;
}

void OnTick()
{
	// Call modules on_trade function
	context.on_trade();
	
	return;	
}



void OnDeinit(const int reason)
{
	context.on_exit();
	
	delete context;
}