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
#include <Basic.mqh>


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

struct Position
{
	double volume;
	double entry_price;
	double average_price;
	ulong positions[];
};

class Context
{	
	public:
	//basic
	CTrade trade;
	COrderInfo order;
	CPositionInfo pos_info;
	Optimizer *optimizer;
	
	//void on_order(MqlTradeTransaction &trans);
	void on_trade(void);
	bool Buy(double volume, string comment);
	bool Sell(double volume, string comment);
	bool ClosePositionByTicket(ulong ticket, string comment);
	bool ClosePositions(string comment);
	
	string stock_code;
	ulong magic_number;
	datetime start_time;
	datetime last_candle_time;
	bool valid_strategy;
	bool is_new_bar;
	bool entries_locked;
	bool daily_locked;
	TickInfo tick;
	ulong pending_order;
	Position position;

	ENUM_TIMEFRAMES periodicity;
	
	CArrayObj *on_trade_nodes;
	CArrayObj *on_order_nodes;
	
	
	double current_price(void) {return tick.tick.bid;}
	bool is_new_day(void) {return optimizer.is_new_day;}
	bool is_positioned(void) {return position.volume != 0;}
	bool is_bought(void) {return position.volume > 0;}
	bool is_sold(void) {return position.volume < 0;}
	int positions_quantity(void) {return ArraySize(position.positions);}
	
	bool check_times(int h_ini, int m_ini, int h_end, int m_end);
	int compare_time(MqlDateTime &mql_time, int hour, int min);
	void set_periodicity(int p);
	ENUM_APPLIED_PRICE get_price_type(price_type_enum p);
	void check_new_bar(void);
	double round_price(double price);
	void check_entry_timeout();
	bool is_testing(void);
	double get_daily_profit(void);
	
	
	Context(string stockCode, ulong magicNumber);
	~Context(){};
	
	private:
	void update_orders(void);
	void reset_position(void);
	void update_position(ulong ticket);
	void load_positions(void);
};

Context::Context(string stockCode, ulong magicNumber)
{
	stock_code = stockCode;
	magic_number = magicNumber;
	trade.SetExpertMagicNumber(magic_number);
	optimizer = new Optimizer();
	start_time = TimeCurrent();
	valid_strategy = true;
	last_candle_time = 0;
	entries_locked = false;
	daily_locked = false;
	pending_order = 0;
	
	on_trade_nodes = new CArrayObj;
	on_order_nodes = new CArrayObj;
	
	load_positions();
	
	logger("Successfull initialization. Number of positions loaded: " + IntegerToString(positions_quantity()));
}

void Context::load_positions(void)
{  
   int total = PositionsTotal();
   for (int i = 0; i < total; i++)
   {
      if (!pos_info.SelectByIndex(i))
         continue;
      
      if (pos_info.Symbol() != stock_code || pos_info.Magic() != magic_number)
         continue;
      
      logger("Initial position identified. Loading positions...");
      
      update_position(pos_info.Ticket());      
   }
}

void Context::on_trade()
{
   // check for order updates
   if (pending_order)
      update_orders();

   ResetLastError();
	if (!SymbolInfoTick(stock_code, tick.tick))
	{
	   logger("Tick error: " + IntegerToString(GetLastError()));
	   return;
	}
	
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

void Context::update_orders(void)
{
   // update last sent order status
   if (pending_order && HistoryOrderSelect(pending_order))
   {      
      // check order state
      if (HistoryOrderGetInteger(pending_order, ORDER_STATE) != ORDER_STATE_FILLED)
      {
         logger("Error! Order in history but not executed. Id: " + IntegerToString(pending_order));
         pending_order = 0;
         return;
      }
      
      // update position info
      ulong position_ticket = HistoryOrderGetInteger(pending_order,ORDER_POSITION_ID);      
      update_position(position_ticket);      
      
      // reset pending order
      pending_order = 0;
   }
}

void Context::update_position(ulong ticket)
{
   if (!pos_info.SelectByTicket(ticket))
   {
      logger("Error selecting position. Something went wrong. Id: " + IntegerToString(ticket));
      return;
   }
   
   append(position.positions, ticket);
   
   // update entry price if not positioned
   if (position.entry_price == 0)      
      position.entry_price = pos_info.PriceOpen();
   // update average price
   position.average_price = (MathAbs(position.volume)*position.average_price + pos_info.Volume()*pos_info.PriceOpen()) / (MathAbs(position.volume) + pos_info.Volume());
   // update volume
   if (pos_info.PositionType() == POSITION_TYPE_BUY)
      position.volume += pos_info.Volume();
   else if (pos_info.PositionType() == POSITION_TYPE_SELL)
      position.volume -= pos_info.Volume();
      
   string msg = StringFormat("Position updated according position ticket %d. \nEntry price: %f \nAverage Price: %f \nVolume: %f",
                              ticket, position.entry_price, position.average_price, position.volume);
      
   logger(msg);
}

bool Context::ClosePositions(string comment)
{
   bool success = true;
   for(int i = 0; i < ArraySize(position.positions); i++)
   {
      success = success && ClosePositionByTicket(position.positions[i], comment);
   }
   
   if (success)
   {
      reset_position();
      
      logger("Position reset after " + comment);
   }
   
   
   return success;
}

bool Context::ClosePositionByTicket(ulong ticket, string comment)
{
   int tries = 0;
	uint result = 0;
   while(tries < MAX_TRIES && result != 10009)
	{
		trade.PositionClose(ticket, comment);
		result = trade.ResultRetcode();
		tries++;
		if(result != 10009)
		{
			Sleep(100);
		}
	}
	if (result == 10009)
	{
	   return true;
	}
	else
	{
	   logger("Error closing position. Ticket: " + IntegerToString(ticket) + trade.ResultRetcodeDescription());
	   return false;
	}
}

void Context::reset_position(void)
{
   position.entry_price = 0;
   position.average_price = 0;
   position.volume = 0;
   ArrayFree(position.positions);
}

bool Context::check_times(int h_ini, int m_ini, int h_end, int m_end)
{
	check_entry_timeout();
		
		
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

/*
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
*/

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

bool Context::Buy(double volume, string comment="")
{
   if (pending_order != 0)
   {
      logger("Blocking order due to pending order. New order reason: " + comment);
      return false;
   }
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
	if (result == 10009)
	{
	   pending_order = trade.ResultOrder();
	   return true;
	}
	else
	{
	   logger("Order couldn't be placed. Code: " + trade.ResultRetcodeDescription());
	   return false;
	}
}

bool Context::Sell(double volume, string comment="")
{
   if (pending_order != 0)
   {
      logger("Blocking order due to pending order. New order reason: " + comment);
      return false;
   }
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
	if (result == 10009)
	{
	   pending_order = trade.ResultOrder();
	   return true;
	}
	else
	{
	   logger("Order couldn't be placed. Code: " + trade.ResultRetcodeDescription());
	   return false;
	}
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

void logger(string msg)
{
   if (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;
	PrintFormat("id: %d - %s", magic_number, msg);
}