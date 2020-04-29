---
title: "SpringBoot2源码解析 ApplicationContextInitializer"
date: 2020-04-28T21:05:39+08:00
categories: ["springboot"]
tags: ["springboot","spring"]
author: "itning"
draft: false
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
---

系统初始化器

```java
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;

/**
 * @author itning
 * @date 2020/4/28 20:43
 */
@Order(1)
public class FirstApplicationContextInitializer implements ApplicationContextInitializer<ConfigurableApplicationContext> {
    @Override
    public void initialize(@NonNull ConfigurableApplicationContext applicationContext) {
        System.out.println("FirstApplicationContextInitializer");
    }
}
```
<!--more-->
实现`ApplicationContextInitializer`接口即可，并且必须是`ConfigurableApplicationContext`子类

如何使其生效？三种方式：

1. 关键代码：`springApplication.addInitializers(new FirstApplicationContextInitializer());`
   
   ```java
   import org.springframework.boot.SpringApplication;
   import org.springframework.boot.autoconfigure.SpringBootApplication;
   import top.itning.springboottest.config.FirstApplicationContextInitializer;
   
   /**
    * @author itning
    */
   @SpringBootApplication
   public class SpringbootTestApplication {
       public static void main(String[] args) {
           //SpringApplication.run(SpringbootTestApplication.class, args);
           SpringApplication springApplication = new SpringApplication(SpringbootTestApplication.class);
           springApplication.addInitializers(new FirstApplicationContextInitializer());
           springApplication.run(args);
       }
   }
```
   
2. 只需要在应用配置文件中`application.yml`配置：`context.initializer.classes=xxx.xxx.xxx.XX`

   ```yml
   context:
     initializer:
       classes: xxx.xxx.xxx.XX
   ```

3. `resources`目录新建`META-INF`文件夹并且新建文件：`spring.factories`

   ```properties
   org.springframeword.context.ApplicationContextInitializer=xxx.xxx.xxx.XX
   ```

源码解析；

```java
public static ConfigurableApplicationContext run(Class<?>[] primarySources, String[] args) {
		return new SpringApplication(primarySources).run(args);
}
```

实例化`SpringApplication`的代码：

```java
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
		this.resourceLoader = resourceLoader;
		Assert.notNull(primarySources, "PrimarySources must not be null");
		this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
		this.webApplicationType = WebApplicationType.deduceFromClasspath();
		setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
		setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
		this.mainApplicationClass = deduceMainApplicationClass();
}
```

关键代码：`setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));`

```java
private <T> Collection<T> getSpringFactoriesInstances(Class<T> type) {
		return getSpringFactoriesInstances(type, new Class<?>[] {});
}
```

泛型`T`即为`ApplicationContextInitializer`

```java
private <T> Collection<T> getSpringFactoriesInstances(Class<T> type, Class<?>[] parameterTypes, Object... args) {
		ClassLoader classLoader = getClassLoader();
		// Use names and ensure unique to protect against duplicates
		Set<String> names = new LinkedHashSet<>(SpringFactoriesLoader.loadFactoryNames(type, classLoader));
		List<T> instances = createSpringFactoriesInstances(type, parameterTypes, classLoader, args, names);
		AnnotationAwareOrderComparator.sort(instances);
		return instances;
}
```

首先，获得类加载器：`ClassLoader classLoader = getClassLoader();`

然后，`Set<String> names = new LinkedHashSet<>(SpringFactoriesLoader.loadFactoryNames(type, classLoader));`通过调用静态方法`SpringFactoriesLoader.loadFactoryNames(type, classLoader)`来获得所有定义`org.springframeword.context.ApplicationContextInitializer`的值

最后进行排序。

当调用`run()`方法时：

```java
prepareContext(context, environment, listeners, applicationArguments, printedBanner);
```

会调用

```java
applyInitializers(context);
```

同过`for`循环来调用`initialize`方法：

```java
protected void applyInitializers(ConfigurableApplicationContext context) {
		for (ApplicationContextInitializer initializer : getInitializers()) {
			Class<?> requiredType = GenericTypeResolver.resolveTypeArgument(initializer.getClass(),
					ApplicationContextInitializer.class);
			Assert.isInstanceOf(requiredType, context, "Unable to call initializer.");
			initializer.initialize(context);
		}
}
```

其中第一个被调用``initialize``的类是`org.springframework.boot.context.config.DelegatingApplicationContextInitializer`，该类会加载在`application.yml`中属性为`private static final String PROPERTY_NAME = "context.initializer.classes";`的类并进行调用`initialize`方法

而`springApplication.addInitializers(new FirstApplicationContextInitializer());`直接将参数加入到`List`集合中。

```java
private List<ApplicationContextInitializer<?>> initializers;

public void addInitializers(ApplicationContextInitializer<?>... initializers) {
		this.initializers.addAll(Arrays.asList(initializers));
}
```

