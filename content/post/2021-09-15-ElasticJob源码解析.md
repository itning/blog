---
title: "ElasticJob源码解析"
date: 2021-09-15T16:40:02+08:00
categories: ["ElasticJob","定时任务"]
tags: ["ElasticJob"]
author: "itning"
draft: false
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
---

> ElasticJob 是面向互联网生态和海量任务的分布式调度解决方案，由两个相互独立的子项目 ElasticJob-Lite 和 ElasticJob-Cloud 组成。 它通过弹性调度、资源管控、以及作业治理的功能，打造一个适用于互联网场景的分布式调度解决方案，并通过开放的架构设计，提供多元化的作业生态。 它的各个产品使用统一的作业 API，开发者仅需一次开发，即可随意部署。
>
> ElasticJob 已于 2020 年 5 月 28 日成为 [Apache ShardingSphere](https://shardingsphere.apache.org/) 的子项目。 欢迎通过[邮件列表](mailto:dev@shardingsphere.apache.org)参与讨论。

ElasticJob下文用EsJob代替

结合源码看：[itning/shardingsphere-elasticjob: 当当网 Elastic-Job 源码解析 (github.com)](https://github.com/itning/shardingsphere-elasticjob)
<!--more-->
# 入口

esjob和spring进行整合入口通过XML文件进行解析和创建esjob实例

通过继承`AbstractBeanDefinitionParser`类进行XML解析

![image-20210914132951812](/images/image-20210914132951812.png)

## ZookeeperRegistryCenter

首先看`com.dangdang.ddframe.job.lite.spring.reg.parser.ZookeeperBeanDefinitionParser`这个类，这个类解析XML转化成`com.dangdang.ddframe.job.reg.zookeeper.ZookeeperConfiguration`配置对象，并执行`com.dangdang.ddframe.job.reg.zookeeper.ZookeeperRegistryCenter`的init方法进行初始化。

这个init方法非常 清晰，通过`ZookeeperConfiguration`配置对象创建一个Curator Zookeeper客户端

```java
@Override
    public void init() {
        log.debug("Elastic job: zookeeper registry center init, server lists is: {}.", zkConfig.getServerLists());
        CuratorFrameworkFactory.Builder builder = CuratorFrameworkFactory.builder()
                .connectString(zkConfig.getServerLists())
                .retryPolicy(new ExponentialBackoffRetry(zkConfig.getBaseSleepTimeMilliseconds(), zkConfig.getMaxRetries(), zkConfig.getMaxSleepTimeMilliseconds()))
                .namespace(zkConfig.getNamespace());
        if (0 != zkConfig.getSessionTimeoutMilliseconds()) {
            builder.sessionTimeoutMs(zkConfig.getSessionTimeoutMilliseconds());
        }
        if (0 != zkConfig.getConnectionTimeoutMilliseconds()) {
            builder.connectionTimeoutMs(zkConfig.getConnectionTimeoutMilliseconds());
        }
        if (!Strings.isNullOrEmpty(zkConfig.getDigest())) {
            builder.authorization("digest", zkConfig.getDigest().getBytes(Charsets.UTF_8))
                    .aclProvider(new ACLProvider() {
                    
                        @Override
                        public List<ACL> getDefaultAcl() {
                            return ZooDefs.Ids.CREATOR_ALL_ACL;
                        }
                    
                        @Override
                        public List<ACL> getAclForPath(final String path) {
                            return ZooDefs.Ids.CREATOR_ALL_ACL;
                        }
                    });
        }
        client = builder.build();
        client.start();
        try {
            if (!client.blockUntilConnected(zkConfig.getMaxSleepTimeMilliseconds() * zkConfig.getMaxRetries(), TimeUnit.MILLISECONDS)) {
                client.close();
                throw new KeeperException.OperationTimeoutException();
            }
            //CHECKSTYLE:OFF
        } catch (final Exception ex) {
            //CHECKSTYLE:ON
            RegExceptionHandler.handleException(ex);
        }
    }
```

`ZookeeperRegistryCenter`除了进行初始化ZK客户端以外还使用了HashMap进行缓存ZK结果，并且实现了对缓存和ZK节点的CRUD方法。

## AbstractJobBeanDefinitionParser

对于每个作业的解析都会在`com.dangdang.ddframe.job.lite.spring.job.parser.common.AbstractJobBeanDefinitionParser`中执行parseInternal方法进行初始化`com.dangdang.ddframe.job.lite.spring.api.SpringJobScheduler`执行器。

执行parseInternal方法时会将注册中心对象传入，并且解析XML以创建`com.dangdang.ddframe.job.lite.config.LiteJobConfiguration`该类。并且此时会将XML写的的监听器进行创建。

```java
@Override
    protected AbstractBeanDefinition parseInternal(final Element element, final ParserContext parserContext) {
        BeanDefinitionBuilder factory = BeanDefinitionBuilder.rootBeanDefinition(SpringJobScheduler.class);
        factory.setInitMethodName("init");
        //TODO 抽象子类
        if ("".equals(element.getAttribute(JOB_REF_ATTRIBUTE))) {
            if ("".equals(element.getAttribute(CLASS_ATTRIBUTE))) {
                factory.addConstructorArgValue(null);
            } else {
                factory.addConstructorArgValue(BeanDefinitionBuilder.rootBeanDefinition(element.getAttribute(CLASS_ATTRIBUTE)).getBeanDefinition());
            }
        } else {
            factory.addConstructorArgReference(element.getAttribute(JOB_REF_ATTRIBUTE));
        }
        factory.addConstructorArgReference(element.getAttribute(REGISTRY_CENTER_REF_ATTRIBUTE));
        factory.addConstructorArgValue(createLiteJobConfiguration(parserContext, element));
        BeanDefinition jobEventConfig = createJobEventConfig(element);
        if (null != jobEventConfig) {
            factory.addConstructorArgValue(jobEventConfig);
        }
        factory.addConstructorArgValue(createJobListeners(element));
        return factory.getBeanDefinition();
    }
```

## SpringJobScheduler

看`com.dangdang.ddframe.job.lite.spring.api.SpringJobScheduler`实例的创建过程。

先从作业注册中心获取实例（`JobRegistry.getInstance()`获取单例）并添加作业实例，作业实例包含本机IP信息和JVM信息，其中作业实例主键为本机IP+@-@+JVM名

例：`192.168.0.110@-@8660`

```java

/**
 * 作业运行实例.
 * 
 * @author zhangliang
 */
@RequiredArgsConstructor
@Getter
@EqualsAndHashCode(of = "jobInstanceId")
public final class JobInstance {
    
    private static final String DELIMITER = "@-@";
    
    /**
     * 作业实例主键.
     */
    private final String jobInstanceId;
    
    public JobInstance() {
        jobInstanceId = IpUtils.getIp() + DELIMITER + ManagementFactory.getRuntimeMXBean().getName().split("@")[0];
    }
    
    /**
     * 获取作业服务器IP地址.
     * 
     * @return 作业服务器IP地址
     */
    public String getIp() {
        return jobInstanceId.substring(0, jobInstanceId.indexOf(DELIMITER));
    }
}

```

对监听器的属性进行赋值

创建调度器`com.dangdang.ddframe.job.lite.internal.schedule.SchedulerFacade`

创建作业门面`com.dangdang.ddframe.job.lite.internal.schedule.LiteJobFacade`

### init

`com.dangdang.ddframe.job.lite.api.JobScheduler`的init方法在类实例化后执行

先通过调用调度器SchedulerFacade的updateJobConfiguration方法更新作业配置：

1. 检查ZK上的作业名和配置的作业名是否有相同的，有的话检查配置的作业执行类是否相同，不相同就报错。
2. 如果ZK上不存在相同的作业名或允许本地覆盖ZK的配置则用本地替换ZK上的作业配置信息
3. 从ZK上获取最新的作业配置信息并反序列化成`com.dangdang.ddframe.job.lite.config.LiteJobConfiguration`

更新完后返回的LiteJobConfiguration即目前生效的作业配置信息

设置该JOB的分片数量

初始化作业调度控制器（com.dangdang.ddframe.job.lite.internal.schedule.JobScheduleController）：

1. 先创建调度器（com.dangdang.ddframe.job.lite.api.JobScheduler#createScheduler），调度器是通过`org.quartz.impl.StdSchedulerFactory`创建的
2. 创建作业信息（org.quartz.JobDetail）

可以看到作业的执行是通过quartz来实现的

作业调度控制器的主要职责就是对作业进行启动暂停恢复下线等操作

作业注册中心注册该作业

调度器注册作业启动信息--这里边做了很多工作，下边详细说明

作业调度控制器根据CRON配置信息进行作业调度

### 调度器注册作业启动信息

所在方法：`com.dangdang.ddframe.job.lite.internal.schedule.SchedulerFacade#registerStartUpInfo`

作业注册中心的监听器管理者（com.dangdang.ddframe.job.lite.internal.listener.ListenerManager） 启用所有监听器

主节点服务（com.dangdang.ddframe.job.lite.internal.election.LeaderService） 选举主节点

作业服务器服务（com.dangdang.ddframe.job.lite.internal.server.ServerService） 持久化作业服务器上线信息

作业运行实例服务（com.dangdang.ddframe.job.lite.internal.instance.InstanceService） 持久化作业服务器上线信息

作业分片服务（com.dangdang.ddframe.job.lite.internal.sharding.ShardingService）设置需要重新分片的标记

作业监控服务（com.dangdang.ddframe.job.lite.internal.monitor.MonitorService） 初始化作业监听服务

调解分布式作业不一致状态服务（com.dangdang.ddframe.job.lite.internal.reconcile.ReconcileService）开启服务

## JOB执行

执行入口：`com.dangdang.ddframe.job.lite.internal.schedule.LiteJob#execute`

首先获取作业执行器，根据JOB类型的不同创建不同的执行器

目前支持的三种执行器如图

![image-20210914170300226](/images/image-20210914170300226.png)

创建对应的执行器后调父类的execute方法执行作业

首先检查作业执行环境，目前检查项是检查本机与注册中心的时间误差秒数是否在允许范围，默认-1不检查

获取作业分片的上下文（com.dangdang.ddframe.job.lite.internal.schedule.LiteJobFacade#getShardingContexts）

1. 判断失效转移是否开启
2. 开启了失效转义并且本作业有失效的分片直接构建分片上下文
3. 如果需要分片且当前节点为主节点, 则作业分片.如果当前无可用节点则不分片
   1. 首先获取可分片的服务实例列表
   2. 如果ZK有分片标识则需要分片，如果ZK上可用服务实例列表为空则不需要分片
   3. 如果需要分片则判断当前机器是不是该作业的leader节点，如果不是等分片完成
   4. 是leader节点则进行分片 具体如何分片下边会说明
4. 获取运行在本机上的分片信息
5. 构建分片上下文信息

判断是否允许可以发送作业事件.

如果允许则发送作业事件

判断如果当前分片还在运行，则标记为错过执行

作业执行前先在ZK节点上注册作业开始执行

判断是否所有的任务均启动完毕，如果有没启动完毕的则等待，如果等待超时则删除作业开始执行标记

如果全部启动完毕则调`com.dangdang.ddframe.job.lite.api.listener.AbstractDistributeOnceElasticJobListener#doBeforeJobExecutedAtLastStarted`通知并清理作业开始执行标记

执行作业判断本机是否有可执行的分片，如果没有则跳过执行

ZK上注册作业启动信息

如果分片数量只有一个则直接执行

如果分片数量多于一个则提交到线程池执行

### 分片策略

分片策略接口：`com.dangdang.ddframe.job.lite.api.strategy.JobShardingStrategy`

![image-20210914175306209](/images/image-20210914175306209.png)

默认为：`com.dangdang.ddframe.job.lite.api.strategy.impl.AverageAllocationJobShardingStrategy`

平均分配算法的分片策略

## ZK存储路径信息

![image-20210914175306210](/images/image-20210914175306210.png)

图片来自[Elastic-Job-Lite 源码分析 —— 作业数据存储 | 芋道源码 —— 纯源码解析博客 (iocoder.cn)](https://www.iocoder.cn/Elastic-Job/job-storage/?self)

