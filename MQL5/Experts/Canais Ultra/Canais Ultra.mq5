//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Enums.mqh>;


//--- input parameters
input group "#---# Magic Number #---#"
input ulong magic_number = 123;
input group "#---# Parâmetros do robô #---#"
input periodicity_enum candle_periodicity; //Tempo gráfico
//input candle_type_enum candle_type; //Modo de operação
input double number_of_stocks = 0.1; //Quantidade por ordem
input ENUM_MA_METHOD tipoMedia = MODE_EMA; //Tipo da média
input int periodoMedia = 23;//Período da média
input double dx = 0.5; //Distância da média (%)
input group "* Stop Gain *"
input bool_enum using_stop_gain; //Usar stop gain
input double stop_gain_distance; //Valor stop gain
input group "* Stop Loss *"
input bool_enum using_stop_loss; //Usar stop loss
input double stop_loss_distance; //Valor do stop loss
input group "* Aumento de Posição *"
input bool_enum using_position_increaser; //Usar aumentos de posição
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
#include <StopLoss.mqh>
#include <MarketStopGain.mqh>
#include <DailyStopLoss.mqh>
#include <DailyStopGain.mqh>
#include <TradesLimit.mqh>
#include <StopMovel.mqh>
#include <DailyBreakEven.mqh>
#include <MultiplePartialStopGain.mqh>
#include <PositionIncreaserMarket.mqh>


Context *context;
TickInfo tick;
ENUM_TIMEFRAMES periodicity;

// Declare modules
StopLoss *stop_loss;
MarketStopGain *stop_gain;
PositionIncreaserMarket *increaser;

int mediaHandle;
double aux[];


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
   
	
	context = new Context(Symbol(), magic_number);
	context.trade.SetTypeFilling(ORDER_FILLING_RETURN);
	
	context.set_periodicity(candle_periodicity);
	periodicity = context.periodicity;
	
	//Set up moving average
   ArraySetAsSeries(aux,true);
	mediaHandle = iMA(_Symbol,periodicity,periodoMedia,0,tipoMedia,PRICE_CLOSE);
	
	// Init modules
	if(using_stop_loss)
	{
		stop_loss = new StopLoss(stop_loss_distance, stop_type_percentual);
		context.on_trade_nodes.Add(stop_loss);
	}
	if(using_stop_gain)
	{
		stop_gain = new MarketStopGain(stop_gain_distance, stop_type_percentual);
		context.on_trade_nodes.Add(stop_gain);
	}	
	if(using_position_increaser)
	{
		increaser = new PositionIncreaserMarket(stop_type_percentual,increase1_distance,increase1_quantity,increase2_distance,increase2_quantity, increase3_distance, increase3_quantity,increase4_distance, increase4_quantity,increase5_distance, increase5_quantity);
		context.on_trade_nodes.Add(increaser);
	}
	
	return(INIT_SUCCEEDED);
}



void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	//context.on_order((MqlTradeTransaction)trans);
}

void OnTick()
{
	// Basic validations
	if(!context.valid_strategy)
		ExpertRemove();
		
	// Call modules on_trade function
	context.on_trade();
	
	check_entry_rule();
	
	return;	
}

void check_entry_rule()
{
   if (context.is_positioned())
      return;
      
	if(getSignal() != "")
	{
		
		if(getSignal() == "lower")
		{
		   context.Buy(number_of_stocks, StringFormat("Compra por distanciamento: %.4f", context.current_price()));
		}
		else if(getSignal() == "upper")
		{
		   context.Sell(number_of_stocks, StringFormat("Venda por distanciamento: %.4f", context.current_price()));
		}
		
		logger(StringFormat("Entrada enviada. Média: %f; Preço: %f", getMedia(), context.current_price()));
	}
}

string getSignal()
{
	double price = context.current_price();
	
	double media = getMedia();
	
	if(price >= media * (1 + dx/100))
		return "upper";
	if(price <= media * (1 - dx/100))
		return "lower";
		
	return "";
}

double getMedia()
{
	CopyBuffer(mediaHandle,0,0,1,aux);
	return aux[0];
}

void OnDeinit(const int reason)
{
	delete context.optimizer;
	// delete on trade nodes
	for(int i = 0; i < context.on_trade_nodes.Total(); i++)
	{
		Node *node = context.on_trade_nodes.At(i);
		delete node;
	}
	delete context.on_trade_nodes;
	
	// delete on order nodes
	for(int i = 0; i < context.on_order_nodes.Total(); i++)
	{
		Node *node = context.on_order_nodes.At(i);
		delete node;
	}
	delete context.on_order_nodes;
	
	delete context;
}