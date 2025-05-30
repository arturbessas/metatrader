//+------------------------------------------------------------------+
//|                                                     CandlesCountRule.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


 /*
#include <Enums.mqh>
#include <Context.mqh>
Context *context;
 */


class CandlesCountRule: public Node
{	
	public:
		
	void on_trade(void);
	
	CandlesCountRule(void);
	CandlesCountRule(int Quantity, bool Trendwise);
	~CandlesCountRule(){};
	
	private:
	int quantity;
	bool trendwise;
	datetime period_in_seconds;
	datetime reference_candle_time;
};

CandlesCountRule::CandlesCountRule(void){}

CandlesCountRule::CandlesCountRule(int Quantity, bool Trendwise)
{
   quantity = Quantity;
   trendwise = Trendwise;
	period_in_seconds = PeriodSeconds(context.periodicity);
	reference_candle_time = 0;
}

void CandlesCountRule::on_trade(void)
{
   datetime current_candle_time = TimeCurrent() / period_in_seconds;
   
   if(context.is_positioned())
   {
      reference_candle_time = current_candle_time;
      return;
   }
      
      
   if(current_candle_time == reference_candle_time)
      return;
   
   int same_direction_count = 0;
   int i = 1;
   bool direction = false;
   
   while(same_direction_count < quantity)
   {
      double open = iOpen(context.stock_code, context.periodicity, i);
      double close = iClose(context.stock_code, context.periodicity, i);
      datetime time = iTime(context.stock_code, context.periodicity, i) / period_in_seconds;
      
      if(time < reference_candle_time)
         break;
      
      
      if(i == 1)
         direction = close > open;
         
      if((close != open) && (close > open == direction))
         same_direction_count++;
         
      else if((close != open) && (close > open != direction))
         break;
         
      // security break
      if(i > 100)
      {
         logger.error("Infinity loop at candles count rule");
         break;
      }
      
      i++;
   }
		
	if(same_direction_count >= quantity && direction == trendwise)
	{
	   context.Buy(number_of_stocks, StringFormat("Compra por %d candles", quantity));
	}
	else if(same_direction_count >= quantity && direction != trendwise)
	{
	   context.Sell(number_of_stocks, StringFormat("Venda por %d candles", quantity));
	}	
}
