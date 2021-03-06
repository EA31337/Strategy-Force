/**
 * @file
 * Implements Force strategy for the Force Index indicator.
 */

// User input params.
INPUT string __Force_Parameters__ = "-- Force strategy params --";  // >>> FORCE <<<
INPUT float Force_LotSize = 0;                                      // Lot size
INPUT int Force_SignalOpenMethod = 0;                               // Signal open method (-7-7)
INPUT float Force_SignalOpenLevel = 0.0f;                           // Signal open level
INPUT int Force_SignalOpenFilterMethod = 1;                         // Signal open filter method
INPUT int Force_SignalOpenBoostMethod = 0;                          // Signal open boost method
INPUT int Force_SignalCloseMethod = 0;                              // Signal close method (-7-7)
INPUT float Force_SignalCloseLevel = 0.0f;                          // Signal close level
INPUT int Force_PriceStopMethod = 0;                                // Price stop method
INPUT float Force_PriceStopLevel = 0;                               // Price stop level
INPUT int Force_TickFilterMethod = 1;                               // Tick filter method
INPUT float Force_MaxSpread = 4.0;                                  // Max spread to trade (pips)
INPUT int Force_Shift = 1;                                          // Shift (relative to the current bar, 0 - default)
INPUT int Force_OrderCloseTime = -20;                               // Order close time in mins (>0) or bars (<0)
INPUT string __Force_Indi_Force_Parameters__ =
    "-- Force strategy: Force indicator params --";                   // >>> Force strategy: Force indicator <<<
INPUT int Force_Indi_Force_Period = 38;                               // Period
INPUT ENUM_MA_METHOD Force_Indi_Force_MA_Method = (ENUM_MA_METHOD)0;  // MA Method
INPUT ENUM_APPLIED_PRICE Force_Indi_Force_Applied_Price = (ENUM_APPLIED_PRICE)2;  // Applied Price
INPUT int Force_Indi_Force_Shift = 0;                                             // Shift

// Structs.

// Defines struct with default user indicator values.
struct Indi_Force_Params_Defaults : ForceParams {
  Indi_Force_Params_Defaults()
      : ForceParams(::Force_Indi_Force_Period, ::Force_Indi_Force_MA_Method, ::Force_Indi_Force_Applied_Price,
                    ::Force_Indi_Force_Shift) {}
} indi_force_defaults;

// Defines struct with default user strategy values.
struct Stg_Force_Params_Defaults : StgParams {
  Stg_Force_Params_Defaults()
      : StgParams(::Force_SignalOpenMethod, ::Force_SignalOpenFilterMethod, ::Force_SignalOpenLevel,
                  ::Force_SignalOpenBoostMethod, ::Force_SignalCloseMethod, ::Force_SignalCloseLevel,
                  ::Force_PriceStopMethod, ::Force_PriceStopLevel, ::Force_TickFilterMethod, ::Force_MaxSpread,
                  ::Force_Shift, ::Force_OrderCloseTime) {}
} stg_force_defaults;

// Struct to define strategy parameters to override.
struct Stg_Force_Params : StgParams {
  ForceParams iparams;
  StgParams sparams;

  // Struct constructors.
  Stg_Force_Params(ForceParams &_iparams, StgParams &_sparams)
      : iparams(indi_force_defaults, _iparams.tf), sparams(stg_force_defaults) {
    iparams = _iparams;
    sparams = _sparams;
  }
};

// Loads pair specific param values.
#include "config/EURUSD_H1.h"
#include "config/EURUSD_H4.h"
#include "config/EURUSD_H8.h"
#include "config/EURUSD_M1.h"
#include "config/EURUSD_M15.h"
#include "config/EURUSD_M30.h"
#include "config/EURUSD_M5.h"

class Stg_Force : public Strategy {
 public:
  Stg_Force(StgParams &_params, string _name) : Strategy(_params, _name) {}

  static Stg_Force *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    ForceParams _indi_params(indi_force_defaults, _tf);
    StgParams _stg_params(stg_force_defaults);
#ifdef __config__
    SetParamsByTf<ForceParams>(_indi_params, _tf, indi_force_m1, indi_force_m5, indi_force_m15, indi_force_m30,
                               indi_force_h1, indi_force_h4, indi_force_h8);
    SetParamsByTf<StgParams>(_stg_params, _tf, stg_force_m1, stg_force_m5, stg_force_m15, stg_force_m30, stg_force_h1,
                             stg_force_h4, stg_force_h8);
#endif
    // Initialize indicator.
    ForceParams force_params(_indi_params);
    _stg_params.SetIndicator(new Indi_Force(_indi_params));
    // Initialize strategy parameters.
    _stg_params.GetLog().SetLevel(_log_level);
    _stg_params.SetMagicNo(_magic_no);
    _stg_params.SetTf(_tf, _Symbol);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_Force(_stg_params, "Force");
    return _strat;
  }

  /**
   * Check if Force Index indicator is on buy or sell.
   *
   * Note: To use the indicator it should be correlated with another trend indicator.
   *
   * @param
   *   _cmd (int) - type of trade order command
   *   period (int) - period to check for
   *   _method (int) - signal method to use by using bitwise AND operation
   *   _level (double) - signal level to consider the signal
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_Force *_indi = Data();
    bool _is_valid = _indi[CURR].IsValid() && _indi[PREV].IsValid() && _indi[PPREV].IsValid();
    bool _result = _is_valid;
    if (_is_valid) {
      switch (_cmd) {
        case ORDER_TYPE_BUY:
          // FI recommends to buy (i.e. FI<0).
          _result = _indi[CURR][0] < 0 && _indi.IsIncreasing(3);
          _result &= _indi.IsIncByPct(_level, 0, 0, 2);
          // Signal: Changing from negative values to positive.
          if (_result && _method != 0) {
            if (METHOD(_method, 0)) _result &= _indi.IsIncreasing(2, 0, 3);
            if (METHOD(_method, 1)) _result &= _indi.IsIncreasing(2, 0, 5);
            // When histogram passes through zero level from bottom up,
            // bears have lost control over the market and bulls increase pressure.
            if (METHOD(_method, 2)) _result &= _indi[PPREV][0] > 0;
          }
          break;
        case ORDER_TYPE_SELL:
          // FI recommends to sell (i.e. FI>0).
          _result = _indi[CURR][0] > 0 && _indi.IsDecreasing(3);
          _result &= _indi.IsDecByPct(-_level, 0, 0, 2);
          if (_result && _method != 0) {
            // When histogram is below zero level, but with the rays pointing upwards (upward trend),
            // then we can assume that, in spite of still bearish sentiment in the market, their strength begins to
            // weaken.
            if (METHOD(_method, 0)) _result &= _indi.IsDecreasing(2, 0, 3);
            if (METHOD(_method, 1)) _result &= _indi.IsDecreasing(2, 0, 5);
            if (METHOD(_method, 2)) _result &= _indi[PPREV][0] < 0;
          }
          break;
      }
    }
    return _result;
  }

  /**
   * Gets price stop value for profit take or stop loss.
   */
  float PriceStop(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, float _level = 0.0) {
    Indi_Force *_indi = Data();
    double level = _level * Chart().GetPipSize();
    double _trail = _level * Market().GetPipSize();
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _default_value = Market().GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _result = _default_value;
    switch (_method) {
      case 1: {
        int _bar_count1 = (int)_level * (int)_indi.GetPeriod();
        _result = _direction > 0 ? _indi.GetPrice(PRICE_HIGH, _indi.GetHighest<double>(_bar_count1))
                                 : _indi.GetPrice(PRICE_LOW, _indi.GetLowest<double>(_bar_count1));
        break;
      }
      case 2: {
        int _bar_count2 = (int)_level * (int)_indi.GetPeriod();
        _result = _direction < 0 ? _indi.GetPrice(PRICE_HIGH, _indi.GetHighest<double>(_bar_count2))
                                 : _indi.GetPrice(PRICE_LOW, _indi.GetLowest<double>(_bar_count2));
        break;
      }
    }
    return (float)_result;
  }
};
