//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.100"

#include <Enums.mqh>;
#include <Logger.mqh>;


//--- input parameters
input group "#---# Magic Number #---#"
input ulong magic_number = 123;
input group "#---# Parâmetros básicos #---#"
input ENUM_TIMEFRAMES candle_periodicity; //Tempo gráfico
input double number_of_stocks = 0.1; //Quantidade por ordem

input group "#---# Entrada por distância da média #---#"
input bool_enum using_ma_distance = true; //Fazer entradas por distanciamento da média
input ENUM_MA_METHOD ma_distance_tipo_media = MODE_EMA; //Tipo da média
input int ma_distance_periodo_media = 23;//Período da média
input double ma_distance_dx = 0.5; //Distância da média (%)

input group "#---# Entrada por candles consecutivos #---#"
input bool_enum using_candles_count; //Fazer entradas por candles consecutivos
input int candles_count_quantity; //Quantidade de candles
input bool_enum candles_count_trendwise = false; //A favor da tendência

input group " * Stop Gain *"
input bool_enum using_stop_gain; //Usar stop gain
input stop_reference_enum stop_gain_reference; //Preço de referência
input double stop_gain_distance; //Valor stop gain(%)

input group " * Stop Gain Financeiro *"
input bool_enum using_financial_stop_gain; //Usar stop gain financeiro
input double financial_stop_gain_value; //Valor($)
input double financial_stop_gain_multiplier = 1.0; //Multiplicador por aumento

input group " * Stop Loss *"
input bool_enum using_stop_loss; //Usar stop loss
input double stop_loss_distance; //Valor do stop loss(%)

input group " * Stop Móvel *"
input bool_enum using_stop_movel; //Usar stop móvel
input double stop_movel_begin; //Valor de ativação(%)
input double stop_movel_distance; //Recuo para stop(%)

input group " * Gradiente * "
input bool_enum using_gradient = false; //Usar Gradiente
input double gradient_distance; //Gradiente - Distância (%)
input int gradient_max_steps; //Gradiente - Limite de aumentos
input double gradient_stop = 0; //Gradiente - Stop Loss (%) 0 = desativado

input group " * Aumento de Posição * "
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

//input group "#---#---# Critérios de otimização #---#---#"
//input bool_enum using_max_months_loss; //Restringir máximo de meses com loss
//input int max_months_loss; //Máximo de meses com loss permitido
//input bool_enum using_max_drawdown; //Restringir drawdown máximo
//input double max_drawdown; //Drawdown máximo permitido
//input bool_enum using_min_trades; //Restringir número mínimo de trades
//input int min_trades; //Número mínimo de trades
//input bool_enum using_days_with_loss; //Restringir máximo de dias consecutivos com prejuízo
//input int days_with_loss; //Máximo de dias consecutivos com loss permitido

#include <Context.mqh>
#include <MovingAverageDistanceRule.mqh>
#include <CandlesCountRule.mqh>
#include <StopLoss.mqh>
#include <MarketStopGain.mqh>
#include <PositionIncreaserMarket.mqh>
#include <Gradient.mqh>
#include <FinancialStopGain.mqh>
#include <StopMovel.mqh>

Logger logger;
Context *context;

// Declare modules
MovingAverageDistanceRule  *ma_distance_rule;
CandlesCountRule           *candles_count_rule;
StopLoss                   *stop_loss;
MarketStopGain             *stop_gain;
PositionIncreaserMarket    *increaser;
Gradient                   *gradient;
FinancialStopGain          *financial_stop_gain;
StopMovel                  *stop_movel;



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

int OnInit()
{	
	context = new Context(Symbol(), magic_number, candle_periodicity);	
	
	// Init modules
	if(using_ma_distance)
	{
	   ma_distance_rule = new MovingAverageDistanceRule(ma_distance_dx, ma_distance_periodo_media, ma_distance_tipo_media);
	   context.on_trade_nodes.Add(ma_distance_rule);
	   
	}

   if(using_candles_count)
	{
	   candles_count_rule = new CandlesCountRule(candles_count_quantity, candles_count_trendwise);
	   context.on_trade_nodes.Add(candles_count_rule);	   
	}	
	
	if(using_financial_stop_gain)
	{
	   financial_stop_gain = new FinancialStopGain(financial_stop_gain_value, financial_stop_gain_multiplier);
	   context.on_order_nodes.Add(financial_stop_gain);
	   context.on_trade_nodes.Add(financial_stop_gain);
	   
	}
	if(using_stop_loss)
	{
		stop_loss = new StopLoss(stop_loss_distance, stop_type_percentual);
		context.on_trade_nodes.Add(stop_loss);
	}
	if(using_stop_gain)
	{
		stop_gain = new MarketStopGain(stop_gain_distance, stop_type_percentual, stop_gain_reference);
		context.on_trade_nodes.Add(stop_gain);
	}	
	if(using_stop_movel)
	{
	   stop_movel = new StopMovel(stop_type_percentual, stop_movel_begin, stop_movel_distance);
	   context.on_trade_nodes.Add(stop_movel);
	}
	if(using_position_increaser)
	{
		increaser = new PositionIncreaserMarket(stop_type_percentual,position_increaser_trendwise,increase1_distance,increase1_quantity,increase2_distance,increase2_quantity, increase3_distance, increase3_quantity,increase4_distance, increase4_quantity,increase5_distance, increase5_quantity);
		context.on_trade_nodes.Add(increaser);
	}
	if(using_gradient)
	{
	   gradient = new Gradient(gradient_distance, gradient_stop, gradient_max_steps);
	   context.on_trade_nodes.Add(gradient);
	}
	
	return(INIT_SUCCEEDED);
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