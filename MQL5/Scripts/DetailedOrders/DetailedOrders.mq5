//+------------------------------------------------------------------+
//|                                                    Smarttbot.mq5 |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                             https://www.smarttbot.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
#property script_show_inputs

enum ENUM_INFORMATION_OUTPUT
  {
   experts_tab = 0,  // The "Experts" tab
   txt_file    = 1,  // The text file
  };
//---
input datetime                from_date   = D'2023.04.11 00:00:00';  // From date
input datetime                to_date     = D'2023.04.11 19:00:00';       // To date
ENUM_INFORMATION_OUTPUT InpOutput   = txt_file;                // Information output
string                  InpFileName = "Detailed Orders.txt";      // File name (only if "Information output" == "The text file")
//---
int file_handle=0;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   if(InpOutput==txt_file)
     {
      //--- delete file
      FileDelete(InpFileName);
      //--- open the file
      ResetLastError();
      
      file_handle=FileOpen(InpFileName,FILE_WRITE|FILE_TXT);
      if(file_handle==INVALID_HANDLE)
        {
         PrintFormat("Failed to open %s file, Error code = %d",InpFileName+".txt",GetLastError());
         return;
        }
     }
//---
   RequestOrders();
}
//+------------------------------------------------------------------+
//| Request trade                                             |
//+------------------------------------------------------------------+
void RequestOrders()
{
	HistorySelect(from_date, to_date);
   uint total_orders=HistoryOrdersTotal();
   ulong deal_order=0;
   
   

   for(uint i=0;i<total_orders;i++)
     {
     	string text = "";
      //--- try to get deals ticket__deal
      deal_order = HistoryOrderGetTicket(i);
      Print(deal_order, i);
      //if(HistoryOrderSelect(deal_order))
        
      long     o_ticket          =HistoryOrderGetInteger(deal_order, ORDER_TICKET);
      long     o_time_setup      =HistoryOrderGetInteger(deal_order, ORDER_TIME_SETUP);
      long     o_type            =HistoryOrderGetInteger(deal_order, ORDER_TYPE);
      long     o_state           =HistoryOrderGetInteger(deal_order, ORDER_STATE);
      long     o_time_expiration =HistoryOrderGetInteger(deal_order, ORDER_TIME_EXPIRATION);
      long     o_time_done       =HistoryOrderGetInteger(deal_order, ORDER_TIME_DONE);
      long     o_time_setup_msc  =HistoryOrderGetInteger(deal_order, ORDER_TIME_SETUP_MSC);
      long     o_time_done_msc   =HistoryOrderGetInteger(deal_order, ORDER_TIME_DONE_MSC);
      long     o_type_filling    =HistoryOrderGetInteger(deal_order, ORDER_TYPE_FILLING);
      long     o_type_time       =HistoryOrderGetInteger(deal_order, ORDER_TYPE_TIME);
      long     o_magic           =HistoryOrderGetInteger(deal_order, ORDER_MAGIC);
      long     o_reason          =HistoryOrderGetInteger(deal_order, ORDER_REASON);
      long     o_position_id     =HistoryOrderGetInteger(deal_order, ORDER_POSITION_ID);
      long     o_position_by_id  =HistoryOrderGetInteger(deal_order, ORDER_POSITION_BY_ID);

      double   o_volume_initial  =HistoryOrderGetDouble(deal_order, ORDER_VOLUME_INITIAL);
      double   o_volume_current  =HistoryOrderGetDouble(deal_order, ORDER_VOLUME_CURRENT);
      double   o_open_price      =HistoryOrderGetDouble(deal_order, ORDER_PRICE_OPEN);
      double   o_sl              =HistoryOrderGetDouble(deal_order, ORDER_SL);
      double   o_tp              =HistoryOrderGetDouble(deal_order, ORDER_TP);
      double   o_price_current   =HistoryOrderGetDouble(deal_order, ORDER_PRICE_CURRENT);
      double   o_price_stoplimit =HistoryOrderGetDouble(deal_order, ORDER_PRICE_STOPLIMIT);

      string   o_symbol          =HistoryOrderGetString(deal_order, ORDER_SYMBOL);
      string   o_comment         =HistoryOrderGetString(deal_order, ORDER_COMMENT);
      string   o_extarnal_id     =HistoryOrderGetString(deal_order, ORDER_EXTERNAL_ID);

      string str_o_time_setup       =TimeToString((datetime)o_time_setup,TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string str_o_type             =EnumToString((ENUM_ORDER_TYPE)o_type);
      string str_o_state            =EnumToString((ENUM_ORDER_STATE)o_state);
      string str_o_time_expiration  =TimeToString((datetime)o_time_expiration,TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string str_o_time_done        =TimeToString((datetime)o_time_done,TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string str_o_type_filling     =EnumToString((ENUM_ORDER_TYPE_FILLING)o_type_filling);
      string str_o_type_time        =TimeToString((datetime)o_type_time,TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string str_o_reason           =EnumToString((ENUM_ORDER_REASON)o_reason);

      text="Order:";
      OutputTest(text);

      text=StringFormat("%-20s %-20s %-20s %-20s %-20s %-20s %-20s %-20s %-20s",
                        "|Ticket","|Time setup","|Type","|State","|Time expiration",
                        "|Time done","|Time setup msc","|Time done msc","|Type filling");
      OutputTest(text);
      text=StringFormat("|%-19d |%-19s |%-19s |%-19s |%-19s |%-19s |%-19I64d |%-19I64d |%-19s",
                        o_ticket,str_o_time_setup,str_o_type,str_o_state,str_o_time_expiration,str_o_time_done,
                        o_time_setup_msc,o_time_done_msc,str_o_type_filling);
      OutputTest(text);
      text=StringFormat("%-20s %-20s %-20s %-20s %-20s",
                        "|Type time","|Magic","|Reason","|Position id","|Position by id");
      OutputTest(text);
      text=StringFormat("|%-19s |%-19d |%-19s |%-19d |%-19d",
                        str_o_type_time,o_magic,str_o_reason,o_position_id,o_position_by_id);
      OutputTest(text);

      text=StringFormat("%-20s %-20s %-20s %-20s %-20s %-20s %-20s",
                        "|Volume initial","|Volume current","|Open price","|sl","|tp","|Price current","|Price stoplimit");
      OutputTest(text);
      text=StringFormat("|%-19.2f |%-19.2f |%-19."+"f |%-19."+
                        "f |%-19."+"f |%-19."+
                        "f |%-19."+"f",
                        o_volume_initial,o_volume_current,o_open_price,o_sl,o_tp,o_price_current,o_price_stoplimit);
      OutputTest(text);
      text=StringFormat("%-20s %-41s %-20s","|Symbol","|Comment","|External id");
      OutputTest(text);
      text=StringFormat("|%-19s |%-40s |%-19s",o_symbol,o_comment,o_extarnal_id);
      OutputTest(text);
        
         
      text="";
      OutputTest(text);
        
     }
//---
   if(InpOutput==txt_file)
      FileClose(file_handle);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Output text                                                      |
//+------------------------------------------------------------------+
void OutputTest(const string text)
  {
   if(InpOutput==txt_file)
      FileWriteString(file_handle,text+"\r\n");
   else
      Print(text);
  }