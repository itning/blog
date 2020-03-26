---
title: "HibernateDialect设置"
date: 2020-03-26T12:15:05+08:00
categories: ["hibernate"]
tags: ["hibernate","mysql","java"]
author: "itning"
draft: false
---

```yaml
spring:
    jpa:		
      database-platform: org.hibernate.dialect.MySQL8Dialect
```
或：

```properties
spring.jpa.database-platform=org.hibernate.dialect.MySQL8Dialect
```

<!--more-->