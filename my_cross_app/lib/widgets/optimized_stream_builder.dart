// lib/widgets/optimized_stream_builder.dart
// 최적화된 StreamBuilder 위젯

import 'package:flutter/material.dart';

class OptimizedStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final T? initialData;
  final bool distinct;

  const OptimizedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.initialData,
    this.distinct = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ?? 
                 _defaultErrorBuilder(context, snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return loadingBuilder?.call(context) ?? 
                 _defaultLoadingBuilder(context);
        }

        if (!snapshot.hasData) {
          return _defaultEmptyBuilder(context);
        }

        return builder(context, snapshot.data!);
      },
    );
  }

  Widget _defaultErrorBuilder(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _defaultLoadingBuilder(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultEmptyBuilder(BuildContext context) {
    return const Center(
      child: Text('데이터가 없습니다'),
    );
  }
}

class MemoizedStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final T? initialData;
  final bool Function(T previous, T next)? shouldRebuild;

  const MemoizedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.initialData,
    this.shouldRebuild,
  });

  @override
  State<MemoizedStreamBuilder<T>> createState() => _MemoizedStreamBuilderState<T>();
}

class _MemoizedStreamBuilderState<T> extends State<MemoizedStreamBuilder<T>> {
  T? _lastData;
  Widget? _lastWidget;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: widget.stream,
      initialData: widget.initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error!) ?? 
                 _defaultErrorBuilder(context, snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return widget.loadingBuilder?.call(context) ?? 
                 _defaultLoadingBuilder(context);
        }

        if (!snapshot.hasData) {
          return _defaultEmptyBuilder(context);
        }

        final data = snapshot.data!;
        
        // 메모이제이션 체크
        if (_lastData != null && 
            (widget.shouldRebuild?.call(_lastData!, data) ?? 
             _lastData == data)) {
          return _lastWidget!;
        }

        _lastData = data;
        _lastWidget = widget.builder(context, data);
        return _lastWidget!;
      },
    );
  }

  Widget _defaultErrorBuilder(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _defaultLoadingBuilder(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultEmptyBuilder(BuildContext context) {
    return const Center(
      child: Text('데이터가 없습니다'),
    );
  }
}

class ConditionalStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final T? initialData;
  final bool Function(T data) condition;
  final Widget Function(BuildContext context)? falseBuilder;

  const ConditionalStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    required this.condition,
    this.loadingBuilder,
    this.errorBuilder,
    this.initialData,
    this.falseBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ?? 
                 _defaultErrorBuilder(context, snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return loadingBuilder?.call(context) ?? 
                 _defaultLoadingBuilder(context);
        }

        if (!snapshot.hasData) {
          return _defaultEmptyBuilder(context);
        }

        final data = snapshot.data!;
        
        if (condition(data)) {
          return builder(context, data);
        } else {
          return falseBuilder?.call(context) ?? 
                 _defaultEmptyBuilder(context);
        }
      },
    );
  }

  Widget _defaultErrorBuilder(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _defaultLoadingBuilder(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultEmptyBuilder(BuildContext context) {
    return const Center(
      child: Text('데이터가 없습니다'),
    );
  }
}
