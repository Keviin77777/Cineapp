import 'package:flutter/material.dart';

class SkeletonLoading extends StatefulWidget {
  const SkeletonLoading({super.key});

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              // Poster skeleton
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 400,
                child: _buildShimmerBox(
                  width: double.infinity,
                  height: 400,
                  borderRadius: 0,
                ),
              ),

              // Content skeleton
              Positioned(
                top: 320,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0E0F12).withOpacity(0.8),
                        const Color(0xFF0E0F12),
                      ],
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 80),
                        // Title
                        _buildShimmerBox(width: 200, height: 32),
                        const SizedBox(height: 12),
                        // Subtitle
                        _buildShimmerBox(width: 150, height: 16),
                        const SizedBox(height: 20),
                        // Rating and info
                        Row(
                          children: [
                            _buildShimmerBox(width: 80, height: 24),
                            const SizedBox(width: 15),
                            _buildShimmerBox(width: 60, height: 24),
                            const SizedBox(width: 15),
                            _buildShimmerBox(width: 100, height: 24),
                          ],
                        ),
                        const SizedBox(height: 25),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildShimmerBox(
                                width: double.infinity,
                                height: 50,
                                borderRadius: 25,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildShimmerBox(
                              width: 50,
                              height: 50,
                              borderRadius: 25,
                            ),
                            const SizedBox(width: 12),
                            _buildShimmerBox(
                              width: 50,
                              height: 50,
                              borderRadius: 25,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        // Synopsis title
                        _buildShimmerBox(width: 100, height: 20),
                        const SizedBox(height: 12),
                        // Synopsis lines
                        _buildShimmerBox(
                          width: double.infinity,
                          height: 16,
                        ),
                        const SizedBox(height: 8),
                        _buildShimmerBox(
                          width: double.infinity,
                          height: 16,
                        ),
                        const SizedBox(height: 8),
                        _buildShimmerBox(width: 250, height: 16),
                        const SizedBox(height: 30),
                        // Cast title
                        _buildShimmerBox(width: 80, height: 20),
                        const SizedBox(height: 15),
                        // Cast items
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    _buildShimmerBox(
                                      width: 70,
                                      height: 70,
                                      borderRadius: 35,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildShimmerBox(width: 70, height: 12),
                                    const SizedBox(height: 4),
                                    _buildShimmerBox(width: 60, height: 10),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 40,
                left: 20,
                child: _buildShimmerBox(
                  width: 40,
                  height: 40,
                  borderRadius: 20,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF151820)!,
            const Color(0xFF151820)!,
            const Color(0xFF151820)!,
          ],
          stops: [
            _animation.value - 0.3,
            _animation.value,
            _animation.value + 0.3,
          ].map((e) => e.clamp(0.0, 1.0)).toList(),
        ),
      ),
    );
  }
}










