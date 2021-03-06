import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:githao/utils/util.dart';
import 'package:githao/widgets/load_more_data_footer.dart';
import 'package:githao/widgets/loading_state.dart';

abstract class BaseGridWidget extends StatefulWidget {
  final perPageRows = 30;
  final bool wantKeepAlive;
  final int crossAxisCount;
  BaseGridWidget({
    this.wantKeepAlive = false,
    this.crossAxisCount = 2,
    Key key,
  }) : assert(crossAxisCount != null && crossAxisCount > 0),
       super(key: key);

  @protected
  BaseGridWidgetState createState();
}

abstract class BaseGridWidgetState<T extends BaseGridWidget, K> extends State<T> with AutomaticKeepAliveClientMixin {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final List<K> _datum = [];
  int _page = 1;
  StateFlag _loadingState = StateFlag.idle;
  bool _lastActionIsReload = true;
  bool _expectHasMoreData = true;

  Future<List<K>> getDatum(final int expectationPage);

  Widget buildItem(K item, int index);

  /// override the method, if there is no need to automatically load the data.
  void afterInitState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) {
        refreshIndicatorKey.currentState.show();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    afterInitState();
  }

  /// 不会被销毁,占内存中
  @override
  bool get wantKeepAlive => widget.wantKeepAlive;

  Future<void> _loadData({bool isReload = true}) async {
    if(_loadingState == StateFlag.loading) return Future;
    int expectationPage;
    if (isReload) {
      expectationPage = 1;
    } else {
      expectationPage = _page + 1;
    }
    Future<List<K>> future = getDatum(expectationPage);
    if(future == null) {
      return Future;
    } else {
      if(mounted) {
        setState(() {
          _lastActionIsReload = isReload;
          _loadingState = StateFlag.loading;
        });
      }
    }
    return future.then<void>((list) {
      if(isReload) {
        _datum.clear();
        _page = 1;
      }
      if(list.isNotEmpty) {
        this._datum.addAll(list);
        if (!isReload) {
          ++_page;
        }
      }
      //判断是否可能还有更多数据
      this._expectHasMoreData = list.length >= widget.perPageRows;
      if(_datum.isEmpty) {
        this._loadingState = StateFlag.empty;
      } else {
        this._loadingState = StateFlag.complete;
      }
      if(mounted) {setState(() {});}
      return;

    }).catchError((e) {
      this._loadingState = StateFlag.error;
      if(isReload) {
        _page = 1;
        _datum.clear();
      }
      if(mounted) {setState(() {});}
      Util.showToast(e is DioError ? e.message : e.toString());
    }).whenComplete(() {
      return;
    });
  }

  @override
  Widget build(BuildContext context) {
    if(widget.wantKeepAlive) {
      super.build(context);
    }
    int gridRows = 0;
    if(_datum.length > 0 ) {
      gridRows = (_datum.length / widget.crossAxisCount).ceil();
    }

    return Container(
      child: Stack(
        children: <Widget>[
          RefreshIndicator(
            key: refreshIndicatorKey,
            onRefresh: _loadData,
            color: Theme.of(context).primaryColor,
            child: ListView.builder(
              itemCount: (_datum.length >= widget.perPageRows) ? gridRows+1 : gridRows,
              itemBuilder: (context, index) {
                if(index < gridRows) {
                  List<Widget> itemsInRow = [];
                  int beginIndex = index * widget.crossAxisCount;
                  for(int i=beginIndex; (i<beginIndex + widget.crossAxisCount); i++) {
                    if(i<_datum.length) {
                      itemsInRow.add(Expanded(child: buildItem(_datum[i], i),),);
                    } else {
                      itemsInRow.add(Expanded(child: Container(),),);
                    }
                  }
                  return Row(
                    children: itemsInRow,
                  );
                } else {
                  if(_expectHasMoreData && _loadingState == StateFlag.complete) {
                    Future.delayed(const Duration(milliseconds: 100)).then((_){
                      _loadData(isReload: false);
                    });
                  }
                  return LoadMoreDataFooter(_expectHasMoreData, flag: _loadingState, onRetry: () {
                    _loadData(isReload: false);
                  },);
                }
              },
            ),
          ),
          LoadingState(_lastActionIsReload ? _loadingState : StateFlag.idle,
            onRetry: (){
              refreshIndicatorKey.currentState.show();
            },
          ),
        ],
      ),
    );
  }
}