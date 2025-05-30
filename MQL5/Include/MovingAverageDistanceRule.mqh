//+------------------------------------------------------------------+
//|                                                     MovingAverageDistanceRule.mqh |
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


class MovingAverageDistanceRule: public Node
{	
	public:
		
	void on_trade(void);
	
	MovingAverageDistanceRule(void);
	MovingAverageDistanceRule(double dx, int periodoMedia, ENUM_MA_METHOD tipoMedia);
	~MovingAverageDistanceRule(){};
	
	private:
	double dx;
	int mediaHandle;
   double aux[];
	double get_current_dx(void);
	double getMedia(void);
};

MovingAverageDistanceRule::MovingAverageDistanceRule(void){}

MovingAverageDistanceRule::MovingAverageDistanceRule(double Dx, int periodoMedia, ENUM_MA_METHOD tipoMedia)
{
   dx = Dx;
	//Set up moving average
   ArraySetAsSeries(aux,true);
	mediaHandle = iMA(_Symbol,context.periodicity,periodoMedia,0,tipoMedia,PRICE_CLOSE);
}

void MovingAverageDistanceRule::on_trade(void)
{
   if (context.is_positioned())
      return;
      
   double current_dx = get_current_dx();
   bool triggered = false;
		
	if(current_dx <= -dx)
	{
	   context.Buy(number_of_stocks, StringFormat("Compra por DX = %.2f%%", current_dx));
	   triggered = true;
	}
	else if(current_dx >= dx)
	{
	   context.Sell(number_of_stocks, StringFormat("Venda por DX = %.2f%%", current_dx));
	   triggered = true;
	}
	
	if(triggered)
	   logger.info(StringFormat("Entrada por DX enviada. Média: %f; Preço: %f; Dx: %f", getMedia(), context.current_price(), current_dx));

}

double MovingAverageDistanceRule::get_current_dx(void)
{
	double price = context.current_price();
	
	double media = getMedia();
	
	return 100 * (price - media) / media;
}

double MovingAverageDistanceRule::getMedia(void)
{
	CopyBuffer(mediaHandle,0,0,1,aux);
	return aux[0];
}