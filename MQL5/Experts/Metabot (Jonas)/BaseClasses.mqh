//+------------------------------------------------------------------+
//|                                                  BaseClasses.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

class Order
{	
	public:
	double price;
	double stop_loss;
	double take_profit;
	string direction;
	double volume;
	Order(void);
	Order(double p, double sl, double tp, string direction, double vol);
	~Order(){};
};
Order::Order(void){}
Order::Order(double p, double sl, double tp, string d, double vol)
{
	price = p;
	stop_loss = sl;
	take_profit = tp;
	direction = d;
	volume = vol;
}

class Position
{	
	public:
	
	string stock_code;
	double volume;
	double price_open;
	
	Position(void);
	Position(string stockCode, double vol, double price);
	~Position(){};
};
Position::Position(void){}
Position::Position(string stockCode, double vol, double price)
{
	stock_code = stockCode;
	volume = vol;
	price_open = price;
}
