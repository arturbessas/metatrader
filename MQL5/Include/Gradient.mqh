//+------------------------------------------------------------------+
//|                                                     Gradient.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

//apagar
 /*
#include <Enums.mqh>
#include <Context.mqh>
Context *context;
 */


class Gradient: public Node
{	
	public:
	double distance;
	int max_steps;
		
	void on_trade(void);
	
	Gradient(void);
	Gradient(double Distance, int maxSteps);
	~Gradient(){};
	
	private:
	void execute_increase(double delta, int current_step);
	void execute_exit(double delta, int current_step);
};

Gradient::Gradient(void){}

Gradient::Gradient(double Distance, int maxSteps)
{
	distance = Distance;
	max_steps = maxSteps;
}

void Gradient::on_trade(void)
{
	if(!context.is_positioned() || max_steps <= 0)
		return;
	
	double current_price = context.current_price();
	double entry_price = context.entry_price();
	int current_step = context.positions_quantity() - 1;
	double signal = context.is_bought() ? -1 : 1;		
	double delta = signal * ((current_price - entry_price) / entry_price * 100);
	
	// check increase
	if(delta >= (current_step + 1) * distance && current_step < max_steps)
	   execute_increase(delta, current_step);
	
	// check exit
	else if(current_step >= 1 && delta <= (current_step - 1) * distance)
	   execute_exit(delta, current_step);
}

void Gradient::execute_increase(double delta, int current_step)
{
   string comment = StringFormat("Increase %d. Delta: %.2f%%", current_step+1, delta);
   
   if(context.is_bought())
      context.Buy(context.number_of_stocks_to_trade(), comment);
   else if(context.is_sold())
      context.Sell(context.number_of_stocks_to_trade(), comment);
      
   logger.debug("Increase sent: " + comment);
}

void Gradient::execute_exit(double delta, int current_step)
{
   string comment = StringFormat("Stop %d. Delta: %.2f%%", current_step, delta);
   
   context.ClosePositionByTicket(context.position.positions[context.positions_quantity() - 1], comment);
}