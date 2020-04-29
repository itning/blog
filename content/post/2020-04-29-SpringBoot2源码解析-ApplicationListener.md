---
title: "SpringBoot2源码解析 ApplicationListener"
date: 2020-04-29T17:44:31+08:00
categories: ["springboot"]
tags: ["springboot","spring"]
author: "itning"
draft: false
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
---

系统监听器

```java
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.lang.NonNull;

/**
 * @author itning
 * @date 2020/4/29 16:59
 */
public class FirstListener implements ApplicationListener<ApplicationStartedEvent> {
    @Override
    public void onApplicationEvent(@NonNull ApplicationStartedEvent event) {
        System.out.println("FirstListener");
    }
}
```

<!--more-->

直接子类

```java
AbstractSubProtocolEvent, 
ApplicationContextEvent, 
BrokerAvailabilityEvent, 
PayloadApplicationEvent, 
RequestHandledEvent, 
TestContextEvent
```

源码：

```java
setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
```

在`spring.factories`文件中

```java
org.springframework.context.ApplicationListener=\
org.springframework.boot.ClearCachesApplicationListener,\
org.springframework.boot.builder.ParentContextCloserApplicationListener,\
org.springframework.boot.cloud.CloudFoundryVcapEnvironmentPostProcessor,\
org.springframework.boot.context.FileEncodingApplicationListener,\
org.springframework.boot.context.config.AnsiOutputApplicationListener,\
org.springframework.boot.context.config.ConfigFileApplicationListener,\
org.springframework.boot.context.config.DelegatingApplicationListener,\
org.springframework.boot.context.logging.ClasspathLoggingApplicationListener,\
org.springframework.boot.context.logging.LoggingApplicationListener,\
org.springframework.boot.liquibase.LiquibaseServiceLocatorApplicationListener
```

同样三种配置方式：


1. 关键代码：`springApplication.addListeners(new FirstListener(), new SecondListener());`
   
    ```java
   import org.springframework.boot.SpringApplication;
   import org.springframework.boot.autoconfigure.SpringBootApplication;
   import top.itning.springboottest.config.FirstApplicationContextInitializer;
   import top.itning.springboottest.listener.FirstListener;
   import top.itning.springboottest.listener.SecondListener;
   
   /**
    * @author itning
    */
   @SpringBootApplication
   public class SpringbootTestApplication {
       public static void main(String[] args) {
           //SpringApplication.run(SpringbootTestApplication.class, args);
           SpringApplication springApplication = new SpringApplication(SpringbootTestApplication.class);
           springApplication.addInitializers(new FirstApplicationContextInitializer());
           springApplication.addListeners(new FirstListener(), new SecondListener());
           springApplication.run(args);
    }
   }
   ```
   
2. 只需要在应用配置文件中`application.yml`配置：`context.initializer.classes=xxx.xxx.xxx.XX`
    
   查看原理：`org.springframework.boot.context.config.DelegatingApplicationListener`
   
   ```yml
   context:
     listener:
       classes: xxx.xxx.xxx.XX
   ```
   
3. `resources`目录新建`META-INF`文件夹并且新建文件：`spring.factories`

   ```properties
   org.springframework.context.ApplicationListener=xxx.xxx.xxx.XX
   ```
