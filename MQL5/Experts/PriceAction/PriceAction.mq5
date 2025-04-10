//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Enums.mqh>;

#define MAX_TRIES 100

//--- input parameters
input group "#---# Parâmetros do robô #---#"
input periodicity_enum candle_periodicity; //Tempo gráfico
input candle_type_enum candle_type; //Modo de operação
input break_type_enum break_type; //Tipo de rompimento
input int number_of_stocks = 1; //Quantidade por ordem
//input allowed_direction_enum allowed_direction; //Sentido das ordens
input trend_type_enum trend_type; //Sentido da operação
input break_direction_enum break_direction; //Sentido do rompimento
input dx_dy_enum using_dx_dy; //Usar distância DX ou filtro DY
input double dx_dy; //Distância (DX) ou variação mínima (DY)
input bool_enum using_max_stock_variation; //Usar filtro de variação do ativo (%)
input double max_stock_variation; //Variação permitida (%)
input bool_enum using_max_open_variation; //Usar filtro de variação do ativo em relação a abertura
input double max_open_variation; //Variação permitida (%)
input bool_enum using_max_candle_variation; //Usar filtro de variação do ativo em relação ao candle anterior
input double max_candle_variation; //Variação permitida (%)
//input bool_enum using_stop_gain; //Usar stop gain
//input order_type_enum order_type; //Tipo de stop gain
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
input group "* Aumento de Posição *"
input bool_enum using_position_increaser; //Usar aumentos de posição
input double increase1_distance=0; //Aumento 1 - Distância
input double increase1_quantity=0; //Aumento 1 - Quantidade
input double increase2_distance=0; //Aumento 2 - Distância
input double increase2_quantity=0; //Aumento 2 - Quantidade
input double increase3_distance=0; //Aumento 3 - Distância
input double increase3_quantity=0; //Aumento 3 - Quantidade
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
#include <StopGain.mqh>
#include <DailyStopLoss.mqh>
#include <DailyStopGain.mqh>
#include <TradesLimit.mqh>
#include <StopMovel.mqh>
#include <DailyBreakEven.mqh>
#include <MultiplePartialStopGain.mqh>
#include <PositionIncreaser.mqh>



struct ReferenceCandle
{
	double min, max;
	datetime time;
};


Context *context;
TickInfo tick;
ReferenceCandle reference_candle;
datetime last_checked_candle_time;
ENUM_TIMEFRAMES periodicity;

// Declare modules
StopLoss *stop_loss;
StopGain *stop_gain;
DailyStopLoss *daily_stop_loss;
DailyStopGain *daily_stop_gain;
TradesLimit *trades_limit;
StopMovel *stop_movel;
DailyBreakEven *daily_break_even;
MultiplePartialStopGain *mpsg;
PositionIncreaser *increaser;




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
	context = new Context(Symbol());
	context.trade.SetTypeFilling(ORDER_FILLING_RETURN);
	if(!context.is_testing())
		ExpertRemove();
	
	reference_candle.max = 0;
	reference_candle.min = 0;
	context.set_periodicity(candle_periodicity);
	periodicity = context.periodicity;
	last_checked_candle_time = TimeCurrent()-1002;
	
	// Init modules
	if(using_daily_loss)
	{
		daily_stop_loss = new DailyStopLoss(daily_loss);
		context.on_trade_nodes.Add(daily_stop_loss);
	}
	if(using_stop_loss)
	{
		stop_loss = new StopLoss(context, stop_loss_distance);
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
	if(using_position_increaser)
	{
		increaser = new PositionIncreaser(increase1_distance,increase1_quantity,increase2_distance,increase2_quantity, increase3_distance, increase3_quantity);
		context.on_order_nodes.Add(increaser);
	}
	
	//mpsg = new MultiplePartialStopGain(stop_loss, 0,0,0,0,0,0,0,0,0,0);	
	
	return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
	
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
	context.on_order((MqlTradeTransaction)trans);
}

void OnTick()
{
	// Basic validations
	if(!context.valid_strategy)
		ExpertRemove();
		
	// Call modules on_trade function
	context.on_trade();
	
	if(!context.check_times(start_hour, start_min, last_hour, last_min))
	{
		reference_candle.max = 0;
		reference_candle.min = 0;
		reference_candle.time = iTime(Symbol(), periodicity, 0);
		return;
	}
		
	tick = context.tick;
	
	check_entry_rule();
	
	return;	
}

void check_entry_rule()
{
	string signal = "";
	
	if(candle_type == candle_type_closed && context.is_new_bar)
	{
		signal = get_entry_signal();
	}
	update_reference_candle();
	if(candle_type == candle_type_open)
	{
		signal = get_entry_signal();
	}
	
	string reason = StringFormat("Max: %f, Min: %f", reference_candle.max, reference_candle.min);
	//Print(reason);
	if(signal != "" && !context.entries_locked && !context.daily_locked)
	{
		context.entries_locked = true;
		int attempts = 0;
		do
		{
			if(signal == "buy")
				context.trade.BuyLimit((double)number_of_stocks, context.round_price(tick.tick.last),Symbol(), 0, 0, ORDER_TIME_GTC, 0, reason);
			else if(signal == "sell")
				context.trade.SellLimit((double)number_of_stocks, context.round_price(tick.tick.last),Symbol(), 0, 0, ORDER_TIME_GTC, 0, reason);
				
			if(context.trade.ResultRetcode() != 10009)
				Sleep(100);
				
		}while(context.trade.ResultRetcode() != 10009 && attempts++ <= MAX_TRIES);		
	}
}

string get_entry_signal()
{
	if(reference_candle.max <= 1)
		return "";
	double price = candle_type == candle_type_closed ? iClose(Symbol(), periodicity, 1) : tick.tick.last;
	
	// dy filter
	if(using_dx_dy == using_dy && reference_candle.max - reference_candle.min < dx_dy)
	{
		reference_candle.max = 0;
		return "";
	}
	
	// max stock variation filter
	if(using_max_stock_variation && !check_max_variation(price))
		return "";
		
	// max open variation
	if(using_max_open_variation && !check_max_open_variation())
		return "";
		
	// max candle variation
	if(using_max_candle_variation && !check_max_candle_variation())
		return "";
	
	if(price > reference_candle.max && break_direction != break_direction_min)
	{
		if(trend_type == trend_type_trend)
			return "buy";
		else
			return "sell";
	}
	if(price < reference_candle.min && break_direction != break_direction_max)
	{
		if(trend_type == trend_type_trend)
			return "sell";
		else
			return "buy";
	}
	
	return "";
}

void update_reference_candle()
{
	datetime current_candle_time = iTime(Symbol(), periodicity, 0);
	datetime last_candle_time = iTime(Symbol(), periodicity, 1);
	
	if(context.pos_info.Select(Symbol()) || current_candle_time - reference_candle.time > 60*60*10)
	{
		reference_candle.max = 0;
		reference_candle.min = 0;
		reference_candle.time = current_candle_time;
		return;
	}	
	
	if(reference_candle.max == 0)
	{
		reference_candle.time = current_candle_time;
		reference_candle.max = 1;
		reference_candle.min = 1;
		return;
	}
	
	if(reference_candle.time != current_candle_time)
	{
		if(reference_candle.max == 1 || (break_type == break_type_prev && last_candle_time != reference_candle.time))
			update_reference_candle_values();
	}
}

void update_reference_candle_values()
{	
	double high_vec[1], low_vec[1];
	
	CopyHigh(Symbol(), periodicity, 1, 1, high_vec);
	CopyLow(Symbol(), periodicity, 1, 1, low_vec);
	
	double delta = using_dx_dy == using_dx ? dx_dy : 0;
	
	reference_candle.time = iTime(Symbol(), periodicity, 1);
	reference_candle.max = high_vec[0] + delta;
	reference_candle.min = low_vec[0] - delta;	
}

bool check_max_variation(double price)
{
	double last_day_close = iClose(Symbol(), PERIOD_D1, 1);
	double delta = MathAbs(last_day_close - price) / last_day_close * 100;
	return delta < max_stock_variation;
}

bool check_max_open_variation(void)
{
	double last_day_close = iClose(Symbol(), PERIOD_D1, 1);
	double today_open = iOpen(Symbol(), PERIOD_D1, 0);
	double delta = MathAbs(last_day_close - today_open) / last_day_close * 100;
	return delta < max_open_variation;
}

bool check_max_candle_variation(void)
{
	double candle1 = iClose(Symbol(), periodicity, 1);
	double candle2 = iClose(Symbol(), periodicity, 2);
	double delta = MathAbs(candle1 - candle2) / candle2 * 100;
	return delta < max_candle_variation;
}