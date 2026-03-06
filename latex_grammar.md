# LaTeX 数学公式速查手册

写博客文章时的 LaTeX 公式语法参考，涵盖从基础到进阶的常用写法。

> **前置条件**：在文章 Front Matter 中添加 `math = true` 启用公式渲染。  
> **渲染引擎**：Hugo 默认支持的 KaTeX（需要在模板中引入，见文末配置说明）。

---

## 1. 行内公式与独立公式

**行内公式**：用单个 `$` 包围，公式嵌在文本中。

```markdown
质能方程 $E = mc^2$ 是物理学中最著名的公式。
```

**独立公式块**：用 `$$` 包围，公式单独居中显示。

```markdown
$$
E = mc^2
$$
```

> **注意**：`$$` 必须各自独占一行，前后不要有多余空格。

---

## 2. 上标与下标

| 写法 | 效果说明 |
| :--- | :--- |
| `x^2` | x 的平方 |
| `x^{10}` | x 的 10 次方（多字符必须用 `{}` 包围） |
| `x_i` | x 下标 i |
| `x_{ij}` | x 下标 ij |
| `x_i^2` | 同时有上下标 |
| `x^{a_1}` | 嵌套：上标中含下标 |

> **规则**：上下标只对紧跟的**单个字符**生效，多字符必须用花括号 `{}` 包围。

---

## 3. 分数

| 写法 | 适用场景 |
| :--- | :--- |
| `\frac{a}{b}` | 标准分数（独立公式中推荐） |
| `\dfrac{a}{b}` | 强制 display 大小（行内也显示标准大小） |
| `\tfrac{a}{b}` | 强制 text 小尺寸（独立公式中缩小） |
| `a/b` | 简单斜线分数（行内简写） |

示例：

```markdown
$$
\frac{\partial L}{\partial w} = \frac{1}{N} \sum_{i=1}^{N} x_i (y_i - \hat{y}_i)
$$
```

---

## 4. 根号

| 写法 | 说明 |
| :--- | :--- |
| `\sqrt{x}` | 平方根 |
| `\sqrt[3]{x}` | 立方根 |
| `\sqrt[n]{x}` | n 次根 |

---

## 5. 求和、求积与极限

**求和** `\sum`：

```markdown
$$
\sum_{i=1}^{n} x_i
$$
```

**求积** `\prod`：

```markdown
$$
\prod_{i=1}^{n} x_i
$$
```

**极限** `\lim`：

```markdown
$$
\lim_{n \to \infty} \frac{1}{n} = 0
$$
```

> 行内公式中上下限默认写在右侧（如 $\sum_{i=1}^{n}$），独立公式中自动在上下方。可用 `\limits` 强制上下方：`\sum\limits_{i=1}^{n}`。

---

## 6. 积分

| 写法 | 说明 |
| :--- | :--- |
| `\int_{a}^{b} f(x) \, dx` | 定积分 |
| `\int f(x) \, dx` | 不定积分 |
| `\iint` | 二重积分 |
| `\iiint` | 三重积分 |
| `\oint` | 环路积分 |

> **排版细节**：积分变量 `dx` 前加 `\,` 插入一个小空格，更规范。

---

## 7. 括号与定界符

**基本括号**：

| 写法 | 说明 |
| :--- | :--- |
| `(` `)` | 圆括号 |
| `[` `]` | 方括号 |
| `\{` `\}` | 花括号（需要转义） |
| `\langle` `\rangle` | 尖括号 ⟨ ⟩ |
| `\|` 或 `\lVert` `\rVert` | 双竖线（范数） ‖ ‖ |
| `|` | 单竖线（绝对值） |

**自适应大小**——用 `\left` 和 `\right` 自动匹配括号高度：

```markdown
$$
\left( \frac{a}{b} \right)^2
$$
```

**手动指定大小**（从小到大）：`\big`、`\Big`、`\bigg`、`\Bigg`

```markdown
$$
\Bigg( \bigg( \Big( \big( x \big) \Big) \bigg) \Bigg)
$$
```

---

## 8. 希腊字母

### 小写

| 写法 | 字母 | 写法 | 字母 |
| :--- | :--- | :--- | :--- |
| `\alpha` | α | `\nu` | ν |
| `\beta` | β | `\xi` | ξ |
| `\gamma` | γ | `\pi` | π |
| `\delta` | δ | `\rho` | ρ |
| `\epsilon` | ε | `\sigma` | σ |
| `\varepsilon` | ε（变体） | `\tau` | τ |
| `\zeta` | ζ | `\upsilon` | υ |
| `\eta` | η | `\phi` | φ |
| `\theta` | θ | `\varphi` | φ（变体） |
| `\iota` | ι | `\chi` | χ |
| `\kappa` | κ | `\psi` | ψ |
| `\lambda` | λ | `\omega` | ω |
| `\mu` | μ | | |

### 大写

首字母大写即可：`\Gamma` Γ、`\Delta` Δ、`\Theta` Θ、`\Lambda` Λ、`\Xi` Ξ、`\Pi` Π、`\Sigma` Σ、`\Phi` Φ、`\Psi` Ψ、`\Omega` Ω

> 没有列出的大写（如 A, B）直接用英文字母即可，它们和希腊大写字母一样。

---

## 9. 修饰符（帽子、横杠、点等）

| 写法 | 说明 | 效果示意 |
| :--- | :--- | :--- |
| `\hat{x}` | 帽子 | x̂ |
| `\bar{x}` | 横杠（均值） | x̄ |
| `\overline{xyz}` | 长横杠（多字符） | |
| `\dot{x}` | 一点（一阶导） | ẋ |
| `\ddot{x}` | 两点（二阶导） | ẍ |
| `\tilde{x}` | 波浪号 | x̃ |
| `\widetilde{xyz}` | 宽波浪号 | |
| `\vec{x}` | 向量箭头 | x⃗ |
| `\overrightarrow{AB}` | 长向量箭头 | |
| `\underline{x}` | 下划线 | |
| `\overbrace{a+b+c}^{n}` | 上花括号标注 | |
| `\underbrace{a+b+c}_{n}` | 下花括号标注 | |

---

## 10. 粗体与字体样式

| 写法 | 用途 | 示例 |
| :--- | :--- | :--- |
| `\boldsymbol{x}` | 粗体（向量/矩阵） | 常用于表示向量 |
| `\mathbf{x}` | 粗体正体 | 矩阵、向量 |
| `\mathbb{R}` | 双线体（黑板粗体） | ℝ（实数集） |
| `\mathcal{L}` | 花体 | ℒ（损失函数） |
| `\mathrm{d}` | 正体 | 微分算子 d |
| `\mathit{text}` | 斜体 | |
| `\text{文字}` | 公式中插入普通文本 | |

常用集合写法：

```markdown
$\mathbb{R}$ 实数集，$\mathbb{Z}$ 整数集，$\mathbb{N}$ 自然数集，$\mathbb{C}$ 复数集
```

---

## 11. 关系运算符

| 写法 | 符号 | 写法 | 符号 |
| :--- | :--- | :--- | :--- |
| `=` | = | `\neq` | ≠ |
| `<` | < | `>` | > |
| `\leq` | ≤ | `\geq` | ≥ |
| `\ll` | ≪ | `\gg` | ≫ |
| `\approx` | ≈ | `\sim` | ∼ |
| `\simeq` | ≃ | `\equiv` | ≡ |
| `\propto` | ∝ | `\in` | ∈ |
| `\notin` | ∉ | `\subset` | ⊂ |
| `\subseteq` | ⊆ | `\supset` | ⊃ |

---

## 12. 二元运算符

| 写法 | 符号 | 写法 | 符号 |
| :--- | :--- | :--- | :--- |
| `+` | + | `-` | − |
| `\times` | × | `\div` | ÷ |
| `\cdot` | · | `\circ` | ∘ |
| `\pm` | ± | `\mp` | ∓ |
| `\otimes` | ⊗ | `\oplus` | ⊕ |
| `\nabla` | ∇ | `\partial` | ∂ |

---

## 13. 箭头

| 写法 | 符号 | 写法 | 符号 |
| :--- | :--- | :--- | :--- |
| `\to` 或 `\rightarrow` | → | `\leftarrow` | ← |
| `\Rightarrow` | ⇒ | `\Leftarrow` | ⇐ |
| `\Leftrightarrow` | ⇔ | `\iff` | ⟺ |
| `\mapsto` | ↦ | `\uparrow` | ↑ |
| `\downarrow` | ↓ | `\nearrow` | ↗ |

---

## 14. 省略号

| 写法 | 说明 |
| :--- | :--- |
| `\cdots` | 居中省略号（用于加法、逗号序列间） |
| `\ldots` | 底部省略号（用于逗号列举） |
| `\vdots` | 竖直省略号（矩阵中） |
| `\ddots` | 对角省略号（矩阵中） |

```markdown
$$
x_1, x_2, \ldots, x_n
$$

$$
x_1 + x_2 + \cdots + x_n
$$
```

---

## 15. 矩阵与数组

**普通矩阵**（无括号）：

```markdown
$$
\begin{matrix}
a & b \\
c & d
\end{matrix}
$$
```

**带括号的矩阵**：

| 环境 | 括号样式 |
| :--- | :--- |
| `pmatrix` | 圆括号 ( ) |
| `bmatrix` | 方括号 [ ] |
| `Bmatrix` | 花括号 { } |
| `vmatrix` | 单竖线（行列式） |
| `Vmatrix` | 双竖线（范数） |

```markdown
$$
\begin{bmatrix}
a_{11} & a_{12} & \cdots & a_{1n} \\
a_{21} & a_{22} & \cdots & a_{2n} \\
\vdots & \vdots & \ddots & \vdots \\
a_{m1} & a_{m2} & \cdots & a_{mn}
\end{bmatrix}
$$
```

**行向量和列向量**：

```markdown
行向量：$\begin{pmatrix} x_1 & x_2 & x_3 \end{pmatrix}$

列向量：$\begin{pmatrix} x_1 \\ x_2 \\ x_3 \end{pmatrix}$
```

---

## 16. 分段函数与条件表达式

```markdown
$$
f(x) = \begin{cases}
x^2 & \text{if } x \geq 0 \\
-x & \text{if } x < 0
\end{cases}
$$
```

> `&` 用于对齐，`\\` 换行，`\text{}` 在公式中插入文字。

---

## 17. 多行公式对齐

**aligned 环境**——多行公式在 `=` 处对齐：

```markdown
$$
\begin{aligned}
\nabla_\theta J(\theta)
&= \mathbb{E}_{\pi_\theta} \left[ \nabla_\theta \log \pi_\theta(a|s) \cdot Q^{\pi}(s,a) \right] \\
&\approx \frac{1}{N} \sum_{i=1}^{N} \nabla_\theta \log \pi_\theta(a_i|s_i) \cdot G_i
\end{aligned}
$$
```

> 用 `&` 标记对齐点，`\\` 换行。

---

## 18. 常用数学函数

这些函数名需要用反斜杠开头，否则会被当作变量渲染为斜体：

| 写法 | 说明 | 写法 | 说明 |
| :--- | :--- | :--- | :--- |
| `\sin` | 正弦 | `\cos` | 余弦 |
| `\tan` | 正切 | `\cot` | 余切 |
| `\log` | 对数 | `\ln` | 自然对数 |
| `\exp` | 指数 | `\min` | 最小值 |
| `\max` | 最大值 | `\arg` | 自变量 |
| `\det` | 行列式 | `\dim` | 维度 |
| `\inf` | 下确界 | `\sup` | 上确界 |

组合使用示例：

```markdown
$$
\arg\min_{\theta} \frac{1}{N} \sum_{i=1}^{N} \mathcal{L}(f_\theta(x_i), y_i)
$$
```

---

## 19. 空格控制

LaTeX 默认忽略公式中的空格，需要手动控制：

| 写法 | 宽度 | 示例用途 |
| :--- | :--- | :--- |
| `\,` | 小空格（3/18 em） | 积分 `dx` 前 |
| `\:` | 中空格（4/18 em） | |
| `\;` | 大空格（5/18 em） | |
| `\quad` | 1 em 空格 | 公式间注释 |
| `\qquad` | 2 em 空格 | 更大间隔 |
| `\!` | 负小空格 | 缩紧间距 |

```markdown
$$
\int_0^1 f(x) \, dx \qquad \text{（定积分示例）}
$$
```

---

## 20. 机器学习 / 深度学习常用公式模板

### 损失函数

```markdown
$$
\mathcal{L}_{\text{total}} = \alpha \mathcal{L}_{\text{cls}} + (1 - \alpha) \mathcal{L}_{\text{reg}}
$$
```

### 交叉熵损失

```markdown
$$
\mathcal{L}_{\text{CE}} = -\sum_{i=1}^{C} y_i \log(\hat{y}_i)
$$
```

### MSE 损失

```markdown
$$
\mathcal{L}_{\text{MSE}} = \frac{1}{N} \sum_{i=1}^{N} (y_i - \hat{y}_i)^2
$$
```

### Softmax

```markdown
$$
\text{softmax}(z_i) = \frac{e^{z_i}}{\sum_{j=1}^{K} e^{z_j}}
$$
```

### 梯度下降

```markdown
$$
\theta_{t+1} = \theta_t - \eta \nabla_\theta \mathcal{L}(\theta_t)
$$
```

### 注意力机制（Attention）

```markdown
$$
\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^\top}{\sqrt{d_k}}\right) V
$$
```

### 高斯分布

```markdown
$$
p(x) = \frac{1}{\sqrt{2\pi}\sigma} \exp\left(-\frac{(x-\mu)^2}{2\sigma^2}\right)
$$
```

### KL 散度

```markdown
$$
D_{\text{KL}}(P \| Q) = \sum_{x} P(x) \log \frac{P(x)}{Q(x)}
$$
```

---

## 附录：Hugo 博客启用数学公式的配置方法

目前博客尚未配置公式渲染引擎，需要以下两步来启用：

### 第一步：添加 KaTeX 脚本

在 `layouts/partials/extend_head.html`（如不存在则新建）中添加：

```html
{{ if or .Params.math .Site.Params.math }}
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/contrib/auto-render.min.js"
    onload="renderMathInElement(document.body, {
        delimiters: [
            {left: '$$', right: '$$', display: true},
            {left: '$', right: '$', display: false}
        ]
    });">
</script>
{{ end }}
```

### 第二步：在文章中启用

在需要公式的文章 Front Matter 中添加：

```toml
+++
title = '文章标题'
math = true
+++
```

或者在 `hugo.toml` 中全局启用：

```toml
[params]
  math = true
```
