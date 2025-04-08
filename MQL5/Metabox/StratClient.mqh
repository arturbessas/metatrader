//+------------------------------------------------------------------+
//|                                                  StratClient.mqh |
//|                                                         Stratbox |
//|                                              https://stratbox.io |
//+------------------------------------------------------------------+
#property copyright "Stratbox"
#property link      "https://stratbox.io"

class StratClient
{   
   public:
   
   StratClient(void){};
	~StratClient(){};
	
	void send_new_deal(
	   ulong  ticket,
	   ulong  magic_number,
	   long   position_id,
	   string symbol,
	   ulong   time_msc,
	   string type,
	   string reason,
	   double volume,
	   double price,
	   string entry,
	   double profit,
	   double swap,
	   double commission
	)
	{
	   string json = "{";
   
      json += StringFormat("\"ticket\":%llu,", ticket);
      json += StringFormat("\"magic_number\":%llu,", magic_number);
      json += StringFormat("\"position_id\":%ld,", position_id);
      json += StringFormat("\"symbol\":\"%s\",", symbol);
      json += StringFormat("\"time_msc\":%llu,", time_msc);
      json += StringFormat("\"type\":\"%s\",", type);
      json += StringFormat("\"reason\":\"%s\",", reason);
      json += StringFormat("\"volume\":%.2f,", volume);
      json += StringFormat("\"price\":%.5f,", price);
      json += StringFormat("\"entry\":\"%s\",", entry);
      json += StringFormat("\"profit\":%.2f,", profit);
      json += StringFormat("\"swap\":%.2f,", swap);
      json += StringFormat("\"commission\":%.2f", commission);
      
      json += "}";
	
	
	
      Print(json);
	};
};