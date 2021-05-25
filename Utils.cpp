struct posManager
{
    int owned_stocks;
    double average_price;
};

void update_position_info(MqlTradeTransaction &trans, posManager &p)
{
    if (trans.order_state != ORDER_STATE_FILLED)
        return;

    if (trans.order_type == ORDER_TYPE_BUY || trans.order_type == ORDER_TYPE_BUY_LIMIT)
        p.owned_stocks += (int)trans.volume;

    else if (trans.order_type == ORDER_TYPE_SELL || trans.order_type == ORDER_TYPE_SELL_LIMIT)
        p.owned_stocks -= (int)trans.volume;

    if (pos.owned_stocks != 0)
    {
        int owned_stocks = MathAbs(p.owned_stocks);
        double price = p.average_price;
        p.average_price = (((owned_stocks - trans.volume) * price) + (trans.volume * trans.price)) / owned_stocks;
    }
}

void logger(string msg)
{
    PrintFormat("id: %d - %s", magic_number, msg);
}

ENUM_MA_METHOD getTipoMedia(int tipo)
{
    switch (tipo)
    {
    case 1:
        return MODE_SMA;
        break;
    case 2:
        return MODE_EMA;
        break;
    default:
        return MODE_SMA;
    }
}

ENUM_TIMEFRAMES getPeriodoGrafico(int periodo)
{
    switch (periodo)
    {
    case 1:
        return PERIOD_M1;
        break;
    case 2:
        return PERIOD_M2;
        break;
    case 3:
        return PERIOD_M3;
        break;
    case 4:
        return PERIOD_M4;
        break;
    case 5:
        return PERIOD_M5;
        break;
    case 6:
        return PERIOD_M6;
        break;
    case 7:
        return PERIOD_M10;
        break;
    case 8:
        return PERIOD_M12;
        break;
    case 9:
        return PERIOD_M15;
        break;
    case 10:
        return PERIOD_M20;
        break;
    case 11:
        return PERIOD_M30;
        break;
    case 12:
        return PERIOD_H1;
        break;
    default:
        return _Period;
    }
}

void add(int &v[], int x)
{
    int size = ArraySize(v);
    ArrayResize(v, size + 1);
    v[size] = x;
}