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
	   string entry  	   	 
	)
	{
      PrintFormat("New deal received:\n"
               "Ticket: %llu\n"
               "Magic Number: %llu\n"
               "Position ID: %ld\n"
               "Symbol: %s\n"
               "Time (ms): %llu\n"
               "Type: %s\n"
               "Reason: %s\n"
               "Volume: %.2f\n"
               "Price: %.5f\n"
               "Entry: %s",
               ticket, magic_number, position_id, symbol, time_msc, type, reason, volume, price, entry);
	};
};