import 'package:flutter/material.dart';

class HomeSkeletonLoading extends StatefulWidget {
  const HomeSkeletonLoading({super.key});

  @override
  State<HomeSkeletonLoading> createState() => _HomeSkeletonLoadingState();
}

class _HomeSkeletonLoadingState extends State<HomeSkeletonLoading>
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
          return SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildShimmerBox(width: 120, height: 30),
                      Row(
                        children: [
                          _buildShimmerBox(width: 40, height: 40, borderRadius: 20),
                          const SizedBox(width: 12),
                          _buildShimmerBox(width: 40, height: 40, borderRadius: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Category tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildShimmerBox(width: 80, height: 35, borderRadius: 18),
                      const SizedBox(width: 12),
                      _buildShimmerBox(width: 80, height: 35, borderRadius: 18),
                      const SizedBox(width: 12),
                      _buildShimmerBox(width: 80, height: 35, borderRadius: 18),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner skeleton
                        SizedBox(
                          height: 500,
                          child: _buildShimmerBox(
                            width: double.infinity,
                            height: 500,
                            borderRadius: 0,
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Section title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildShimmerBox(width: 150, height: 24),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Horizontal list
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: 5,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildShimmerBox(
                                  width: 130,
                                  height: 200,
                                  borderRadius: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Another section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildShimmerBox(width: 120, height: 24),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Another horizontal list
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: 5,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildShimmerBox(
                                  width: 130,
                                  height: 200,
                                  borderRadius: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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










