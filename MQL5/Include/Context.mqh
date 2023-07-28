//+------------------------------------------------------------------+
//|                                                      Context.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

#include <Arrays\ArrayObj.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Optimizer.mqh>
#include <Object.mqh>


#define TIMEOUT 60
#define MAX_TRIES 5 

struct TickInfo
{
	MqlTick tick;
	MqlDateTime time;
};


class Node: public CObject
{
	public:
	virtual void on_trade(void){};
	virtual void on_order(MqlTradeTransaction &trans){};
	Node(void){};
	~Node(){};
};

class Rule: public Node
{
	public:
	string Signal;	
	Rule(void){};
	~Rule(){};
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
	void on_trade(void);
	bool Buy(int volume, string comment);
	bool Sell(int volume, string comment);
	
	string stock_code;
	datetime start_time;
	datetime last_candle_time;
	bool valid_strategy;
	bool is_new_bar;
	bool entries_locked;
	bool daily_locked;
	TickInfo tick;
	double entry_price;
	ENUM_TIMEFRAMES periodicity;
	
	CArrayObj *on_trade_nodes;
	CArrayObj *on_order_nodes;
	
	
	double current_price(void) {return tick.tick.last;}
	bool is_new_day(void) {return optimizer.is_new_day;}
	
	bool check_times(int h_ini, int m_ini, int h_end, int m_end);
	int compare_time(MqlDateTime &mql_time, int hour, int min);
	void set_periodicity(int p);
	ENUM_APPLIED_PRICE get_price_type(price_type_enum p);
	void check_new_bar(void);
	double round_price(double price);
	void check_entry_timeout();
	bool is_testing(void);
	double get_daily_profit(void);
	
	Context(string stockCode);
	~Context(){};		
};

Context::Context(string stockCode)
{
	stock_code = stockCode;
	optimizer = new Optimizer();
	start_time = TimeCurrent();
	valid_strategy = true;
	last_candle_time = 0;
	entries_locked = false;
	daily_locked = false;
	entry_price = 0;
	
	on_trade_nodes = new CArrayObj;
	on_order_nodes = new CArrayObj;
}

void Context::on_trade()
{
	SymbolInfoTick(stock_code, tick.tick);
	
	//apagar
	double last = tick.tick.last;
	
	//optmization checks
	optimizer.on_trade();
	
	if(optimizer.is_new_day)
		daily_locked = false;	

	for(int i = 0; i < on_trade_nodes.Total(); i++)
	{
		Node *node = on_trade_nodes.At(i);
		node.on_trade();
	}
}

bool Context::check_times(int h_ini, int m_ini, int h_end, int m_end)
{
	check_entry_timeout();
		
	TimeToStruct(tick.tick.time, tick.time);	
	
	if(compare_time(tick.time, elim_hour, elim_min) >= 0)
	{
		trade.PositionClose(stock_code);
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

void Context::check_new_bar()
{
	datetime current_candle_time = iTime(stock_code, periodicity, 0);
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
	if(StringFind(stock_code, "WIN") >= 0)
		min_var = 5.0;
	else if(StringFind(stock_code, "WDO") >= 0)
		min_var = 0.5;
	else
		min_var = 0.1;
	double ticks = price / min_var;
	return round(ticks) * min_var;
}

void Context::check_entry_timeout(void)
{
	if(pos_info.Select(stock_code))
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
		if(pos_info.Select(stock_code))
		{
			if(entry_price == 0)
				entry_price = trans.price;
		}
		else
			entry_price = 0;
	}
	
	for(int i = 0; i < on_order_nodes.Total(); i++)
	{
		Node *node = on_order_nodes.At(i);
		node.on_order((MqlTradeTransaction)trans);
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
	
	if(pos_info.Select(stock_code))
	{
		result += pos_info.Profit();
	}
	
	return result;
}

bool Context::Buy(int volume, string comment="")
{
	int tries = 0;
	uint result = 0;
	while(tries < MAX_TRIES && result != 10009)
	{
		trade.Buy(volume, stock_code, tick.tick.ask, 0, 0, comment);
		result = trade.ResultRetcode();
		tries++;
		if(result != 10009)
		{
			Sleep(100);
		}
	}
	return result == 10009;
}

bool Context::Sell(int volume, string comment="")
{
	int tries = 0;
	uint result = 0;
	while(tries < MAX_TRIES && result != 10009)
	{
		trade.Sell(volume, stock_code, tick.tick.bid, 0, 0, comment);
		result = trade.ResultRetcode();
		tries++;
		if(result != 10009)
		{
			Sleep(100);
		}
	}
	return result == 10009;
}

void Context::set_periodicity(int p)
{
	if(p == 0)
		periodicity = PERIOD_M1;
	else if(p == 1)
		periodicity = PERIOD_M5;
	else if(p == 2)
		periodicity = PERIOD_M10;
	else if(p == 3)
		periodicity = PERIOD_M15;
	else if(p == 4)
		periodicity = PERIOD_M30;
	else if(p == 5)
		periodicity = PERIOD_H1;
	else if(p == 6)
		periodicity = PERIOD_D1;
	else
		periodicity = PERIOD_M1;
}

ENUM_APPLIED_PRICE Context::get_price_type(price_type_enum p)
{
	if(p == price_type_close)
		return PRICE_CLOSE;
	if(p == price_type_open)
		return PRICE_OPEN;
	if(p == price_type_high)
		return PRICE_HIGH;
	if(p == price_type_low)
		return PRICE_LOW;	
	else
		return PRICE_CLOSE;
}