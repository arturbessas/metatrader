//+------------------------------------------------------------------+
//|                                                   StockCodes.mqh |
//|                        Artur Bessas (artur.bessas@smarttbot.com) |
//|                                        https://www.smarttbot.com |
//+------------------------------------------------------------------+
#property copyright "Artur Bessas (artur.bessas@smarttbot.com)"
#property link      "https://www.smarttbot.com"

string stockCodes[];

add(stockCodes, "ALPA4");
add(stockCodes, "ABEV3");
add(stockCodes, "AMER3");
add(stockCodes, "ASAI3");
add(stockCodes, "AZUL4");
add(stockCodes, "B3SA3");
add(stockCodes, "BIDI11");
add(stockCodes, "BRML3");
add(stockCodes, "CRFB3");
add(stockCodes, "CMIG4");
add(stockCodes, "CIEL3");
add(stockCodes, "CVCB3");
add(stockCodes, "ELET3");
add(stockCodes, "EQTL3");
add(stockCodes, "ITSA4");
add(stockCodes, "RENT3");
add(stockCodes, "LREN3");



void add(string &v[], string x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}