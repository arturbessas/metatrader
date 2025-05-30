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

enum metrics_enum
{
	p50_pred_amplitude,
	p90_pred_amplitude
};

#define DATETIME_COLUMN "Data_Operacao_D+1"
#define LARGURA_COLUMN  "Largura_Intervalo_p10_p90"

// inputs

input group "#---# Output do modelo #---#"
input string csv_filename = "input.csv"; //Arquivo com dados do modelo
input ulong magic_number = 13; //Magic number

input group "#---# Critérios de entrada #---#"
input double number_of_stocks = 1; //Número de ativos
input metrics_enum rule_used_metric; //Métrica utilizada
input double rule_entry_percentage; //(%) mínima para a entrada
input double rule_max_largura; //Largura_Intervalo_p10_p90 máxima

input group "#---# Stop Gain #---#"
input bool_enum using_stop_gain; //Usar stop gain
input double stop_gain_distance; //Valor stop gain (pts)

input group "#---# Stop Loss #---#"
input bool_enum using_stop_loss; //Usar stop loss
input double stop_loss_distance; //Valor stop loss (pts)

input group "#---# Limites diários #---#"
input bool_enum using_trades_limit; //Usar limite diário de trades
input int trades_limit = 3; //Limite diário de trades
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
#include "EntryRule.mqh"

// Declare modules
Logger 							logger;
Context 							*context;
StopLoss                   *stop_loss;
MarketStopGain             *stop_gain;
PositionIncreaserMarket    *increaser;
InvistaIARule					*entry_rule;


int OnInit()
{	
	context = new Context(Symbol(), magic_number, Period());
	
	entry_rule = new InvistaIARule(EnumToString(rule_used_metric), rule_entry_percentage, rule_max_largura);
	context.on_trade_nodes.Add(entry_rule);
	
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
	
	return INIT_SUCCEEDED;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	context.on_order((MqlTradeTransaction)trans);
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