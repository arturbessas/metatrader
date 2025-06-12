//+------------------------------------------------------------------+
//|                                                     StopLoss.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


/*
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Context.mqh>
CTrade trade;
CPositionInfo pos_info;
Context context;
*/


class DayTrade: public Node
{	
	public:
	datetime time;
	bool triggered;
		
	void on_trade(void);
	void on_daily_reset(void);
	
	DayTrade(void);
	DayTrade(datetime Time);
	~DayTrade(){};
};

DayTrade::DayTrade(void){}

DayTrade::DayTrade(datetime Time)
{
	this.time = DatetimeToTime(Time);
	this.triggered = false;
}

void DayTrade::on_trade(void)
{	
	if(this.triggered)
		return;
	
	datetime now_time = DatetimeToTime(TimeCurrent());
	
	if(now_time >= this.time)
	{
		this.triggered = context.ClosePositions("Day trade elimination");
		context.lock_the_day(StringFormat("Day trade time: %s >= %s", TimeToString(now_time, TIME_MINUTES), TimeToString(this.time, TIME_MINUTES)));
	}
}

void DayTrade::on_daily_reset(void)
{
	this.triggered = false;
}