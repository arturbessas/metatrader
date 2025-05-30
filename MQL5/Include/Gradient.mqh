//+------------------------------------------------------------------+
//|                                                     Gradient.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


 /*
#include <Enums.mqh>
#include <Context.mqh>
#include <Logger.mqh>
Context *context;
Logger *logger;
 */


class Gradient: public Node
{	
	public:
	double distance;
	int max_steps;
	double stop_distance;
		
	void on_trade(void);
	
	Gradient(void);
	Gradient(double Distance, double stopDistance, int maxSteps);
	~Gradient(){};
	
	private:
	void execute_increase(double delta, int current_step);
	void execute_exit(double delta, int current_step);
	void execute_stop(double delta, int current_step);
};

Gradient::Gradient(void){}

Gradient::Gradient(double Distance, double stopDistance, int maxSteps)
{
	distance = Distance;
	stop_distance = stopDistance;
	max_steps = maxSteps;
}

void Gradient::on_trade(void)
{
	if(!context.is_positioned() || max_steps <= 0)
		return;
	
	double current_price = context.current_price();
	double entry_price = context.entry_price();
	ulong first_position_ticket = context.position.positions[0];
	double first_position_price = context.get_position_price(first_position_ticket);
	int current_step = context.positions_quantity() - 1;
	double signal = context.is_bought() ? -1 : 1;		
	double entry_price_delta = signal * (current_price/entry_price - 1) * 100;
	double first_position_delta = signal * (current_price/first_position_price - 1) * 100;
	
	// check increase
	if(first_position_delta >= (current_step + 1) * distance && current_step < max_steps)
	   execute_increase(entry_price_delta, current_step);
	
	// check exit
	else if(current_step >= 1 && first_position_delta <= (current_step - 1) * distance)
	   execute_exit(entry_price_delta, current_step);
	   
	// check stop
	else if(stop_distance && first_position_delta > stop_distance)
	   execute_stop(first_position_delta, current_step);
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
   string comment = StringFormat("Exit %d. Delta: %.2f%%", current_step, delta);
   
   context.ClosePositionByTicket(context.position.positions[context.positions_quantity() - 1], comment);
}

void Gradient::execute_stop(double delta, int current_step)
{
   string comment = StringFormat("Grad stop: %.2f%%. New step: %d", delta, current_step-1);
   
   context.ClosePositionByTicket(context.position.positions[0], comment);
}
