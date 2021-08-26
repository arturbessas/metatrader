//+------------------------------------------------------------------+
//|                                                      Context.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Optimizer.mqh>

#define TIMEOUT 60

struct TickInfo
{
	MqlTick tick;
	MqlDateTime time;
};

class Context
{	
	public:
	//basic
	CTrade trade;
	COrderInfo order;
	CPositionInfo pos_info;
	Optimizer *optimizer;
	
	void on_order(MqlTradeTransaction &trans);
	
	
	datetime start_time;
	datetime last_candle_time;
	bool valid_strategy;
	bool is_new_bar;
	bool entries_locked;
	bool daily_locked;
	TickInfo tick;
	double entry_price;
	
	double current_price(void) {return tick.tick.last;}
	
	bool valid_tick(int h_ini, int m_ini, int h_end, int m_end);
	int compare_time(MqlDateTime &mql_time, int hour, int min);
	ENUM_TIMEFRAMES get_periodicity(int p);
	void check_new_bar(void);
	double round_price(double price);
	void check_entry_timeout();
	bool is_testing(void);
	double get_daily_profit(void);
	
	Context(void);
	~Context(){};		
};

Context::Context(void)
{
	optimizer = new Optimizer();
	start_time = TimeCurrent();
	valid_strategy = true;
	last_candle_time = 0;
	entries_locked = false;
	daily_locked = false;
	entry_price = 0;
}

bool Context::valid_tick(int h_ini, int m_ini, int h_end, int m_end)
{
	if(!SymbolInfoTick(Symbol(), tick.tick))
		return false;
		
	check_entry_timeout();
		
	TimeToStruct(tick.tick.time, tick.time);
	
	//optmization checks
	optimizer.on_trade();
	
	if(optimizer.is_new_day)
		daily_locked = false;
	
	if(compare_time(tick.time, elim_hour, elim_min) >= 0)
	{
		trade.PositionClose(Symbol());
		return false;
	}
	
	if(compare_time(tick.time, h_ini, m_ini) < 0)
		return false;
	
	if(compare_time(tick.time, h_end, m_end) > 0)
		return false;	
		
	check_new_bar();
		
	return true;	
}

int Context::compare_time(MqlDateTime &mql_time, int hour, int min)
{
	if(mql_time.hour == hour && mql_time.min == min)
		return 0;
	if(mql_time.hour > hour || (hour == mql_time.hour && mql_time.min > min))
		return 1;
	else
		return -1;
}

ENUM_TIMEFRAMES Context::get_periodicity(int p)
{
	if(p == 0)
		return PERIOD_M1;
	if(p == 1)
		return PERIOD_M5;
	if(p == 2)
		return PERIOD_M10;
	if(p == 3)
		return PERIOD_M15;
	if(p == 4)
		return PERIOD_M30;
	if(p == 5)
		return PERIOD_H1;
	
	return PERIOD_M1;
}

void Context::check_new_bar()
{
	datetime current_candle_time = iTime(Symbol(), periodicity, 0);
	if(last_candle_time != current_candle_time)
	{
		last_candle_time = current_candle_time;
		is_new_bar = true;
	}
	else
	{
		is_new_bar = false;
	}
}

double Context::round_price(double price)
{
	double min_var = 0.01;
	if(StringFind(Symbol(), "WIN") >= 0)
		min_var = 5.0;
	else if(StringFind(Symbol(), "WDO") >= 0)
		min_var = 0.5;
	double ticks = price / min_var;
	return round(ticks) * min_var;
}

void Context::check_entry_timeout(void)
{
	if(pos_info.Select(Symbol()))
		return;
	
	for(int i = 0; i < OrdersTotal(); i++)
	{
		order.SelectByIndex(i);
		if(TimeCurrent() - order.TimeSetup() > TIMEOUT)
		{
			trade.OrderDelete(order.Ticket());
			entries_locked = false;
		}
	}	 
}

void Context::on_order(MqlTradeTransaction &trans)
{
	if(trans.order_state == ORDER_STATE_FILLED)
	{
		entries_locked = false;
		if(pos_info.Select(Symbol()))
		{
			if(entry_price == 0)
				entry_price = trans.price;
		}
		else
			entry_price = 0;
	}
}

bool Context::is_testing(void)
{
	if(!MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION) && !MQLInfoInteger(MQL_FORWARD))
	{
		MessageBox("EA exclusivo para testes. Para operar Price Action, acesse smarttbot.com");
		return false;
	}
	return true;
}

double Context::get_daily_profit(void)
{	
	HistorySelect(TimeCurrent() - 12*60*60, TimeCurrent()); // now - 12h until now
	ulong ticket;
	double result = 0;
	
	for(int i = 0; i < HistoryDealsTotal(); i++)
	{
		ticket = HistoryDealGetTicket(i);
		result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
	}
	
	if(pos_info.Select(Symbol()))
	{
		result += pos_info.Profit();
	}
	
	return result;
}