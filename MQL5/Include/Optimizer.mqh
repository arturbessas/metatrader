//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

input group "#---#---# Critérios de otimização #---#---#"
input bool using_max_months_loss; //Restringir máximo de meses com loss
input int max_months_loss; //Máximo de meses com loss permitido
input bool using_min_trades_per_day; //Restringir média mínima de trades por dia
input double min_trades_per_day; //Número mínimo de trades
input bool using_max_weeks; //Restringir máximo de semanas com loss
input double max_weeks_percentage; //Porcentagem máxima de semanas com loss
input bool using_max_dd; //Restringir drawdown máximo
input double max_dd; //Drawdown máximo permitido


//apagar
/*
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
*/


class Optimizer
{	
	public:
	MqlDateTime last_time;
	double opt_result;
	int months_with_loss;
	int days_with_market;
	int number_of_weeks;
	bool is_new_day;
	int weeks_with_loss;
		
	void on_trade(void);
	
	void check_monthly_loss(void);
	void check_new_day(void);
	void check_new_week(void);
	void check_new_month(void);
	void check_trades_average(void);
	
	Optimizer(void);
	~Optimizer(){};		
};

Optimizer::Optimizer(void)
{
	TimeCurrent(last_time);
	opt_result = 0.0;
	months_with_loss = 0;
	days_with_market = 0;
	number_of_weeks = 0;
	weeks_with_loss = 0;
}


void Optimizer::on_trade(void)
{
	is_new_day = false;
	check_new_day();
	check_new_month();			
	check_new_week();
	
	last_time = context.tick.time;
}

void Optimizer::check_new_month(void)
{
	if(context.tick.time.mon == last_time.mon)
		return;
	if(using_max_months_loss)
		check_monthly_loss();
}

void Optimizer::check_new_day(void)
{
	if(context.tick.time.day == last_time.day)
		return;
		
	days_with_market++;
	is_new_day = true;
	
	if(using_min_trades_per_day)
		check_trades_average();
}

void Optimizer::check_monthly_loss(void)
{
	datetime ini = StringToTime(StringFormat("%d.%d.01 06:00:00", last_time.year, last_time.mon));
	datetime fin = StringToTime(StringFormat("%d.%d.01 06:00:00", context.tick.time.year, context.tick.time.mon));
	
	HistorySelect(ini,fin);
	ulong ticket;
	double result = 0;
	
	for(int i = 0; i < HistoryDealsTotal(); i++)
	{
		ticket = HistoryDealGetTicket(i);
		result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
	}
	
	if(result < 0)
	{
		months_with_loss++;	
	}
	
	if(months_with_loss > max_months_loss)
	{
		opt_result -= 200;
		ExpertRemove();
	}
	else
	{
		opt_result += 1.0;
	}
}

void Optimizer::check_trades_average(void)
{
	HistorySelect(context.start_time, TimeCurrent());
	int trades = HistoryDealsTotal();
	double average = trades / days_with_market;
	if(days_with_market > 10 && average < min_trades_per_day / 2)
	{
		opt_result -= 200;
		ExpertRemove();
	}
}

void Optimizer::check_new_week(void)
{
	if(!(using_max_weeks && is_new_day && context.tick.time.day_of_week == 1))
		return;
		
	number_of_weeks++;
	
	datetime start_date = TimeCurrent() - 60*60*24*8; //today - 8 days
	HistorySelect(start_date, TimeCurrent());
	
	ulong ticket;
	double result = 0;

	for(int i = 0; i < HistoryDealsTotal(); i++)
	{
		ticket = HistoryDealGetTicket(i);
		result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
	}
	
	if(result < 0)
		weeks_with_loss++;	
}