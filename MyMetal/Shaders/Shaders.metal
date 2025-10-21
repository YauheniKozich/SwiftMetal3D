
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;    // Добавляем цвет для каждой вершины
};

vertex VertexOut vertex_main(const device float3* vertexArray [[buffer(0)]],
                             constant float4x4 &mvp [[buffer(1)]],
                             const device float3* colors [[buffer(2)]], // Теперь передаём цвета вместо текстурных координат
                             uint id [[vertex_id]]) {
    VertexOut out;
    out.position = mvp * float4(vertexArray[id], 1.0);
    out.color = colors[id];  // Получаем цвет для вершины

    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // Используем цвет, переданный из вершинного шейдера
    return float4(in.color, 1.0);
}
