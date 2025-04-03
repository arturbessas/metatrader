//+------------------------------------------------------------------+
//|                                                  RolloutRule.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"


// /*
#include <Enums.mqh>
#include <Context.mqh>
Context *context;
 */


class RolloutRule: public Node
{	
	public:
		
	void on_trade(void);
	string get_next_expiration(void);
	string data[];
	int data_size;
	
	RolloutRule(void);
	RolloutRule();
	~RolloutRule(){};
	
};

RolloutRule::RolloutRule(void){}

RolloutRule::RolloutRule()
{
	string filename = StringSubstr(context.stock_code, 0, 3) + ".json";
   int file = FileOpen(filename, FILE_ANSI);
   string raw_data = FileReadString(file);
   FileClose(file);
   // Trim []
   raw_data = StringSubstr(raw_data, 1, StringLen(raw_data) - 2);
   // Remove '"' and spaces
   StringReplace(raw_data, "\"", "");
   StringReplace(raw_data, " ", "");
      
   StringSplit(raw_data, StringGetCharacter(",", 0), data);
   data_size = ArraySize(data);
}

void RolloutRule::on_trade(void)
{
	if(!context.is_positioned())
		return;
	
	string next_expiration = get_next_expiration();
}

void RolloutRule::get_next_expiration(void)
{
   string formatted_today = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(formatted_today, ".", "-");
   
   for(int i=0;i<data_size;i++)
   {
      if(data[i] > formatted_today)
         return 
   }
   
   
}

void RolloutRule::execute_exit(double delta, int current_step)
{
   string comment = StringFormat("Stop %d. Delta: %.2f%%", current_step, delta);
   
   context.ClosePositionByTicket(context.position.positions[context.positions_quantity() - 1], comment);
}